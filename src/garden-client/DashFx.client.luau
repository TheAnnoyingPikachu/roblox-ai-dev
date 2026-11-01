--!strict
-- Splash Dash on the client (GDD T7, T8; docs/architecture/garden.md section 6): obstacles driven by
-- DashRules.pose from server time, knockback on this client's own character, platform carry, the
-- race HUD (timer, place, checkpoint pips, 3-2-1-GO, splash text), the "starts in" pill for ready
-- players, the results card and the pad prompt text. Sends nothing: every outcome is the server's.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DashRules = require(Shared:WaitForChild("DashRules"))
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local fx = ReplicatedStorage:WaitForChild("GardenRemotes"):WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer :: Player
local UI = ClientState.UI
local SFX = ClientState.SFX
local new, corner, stroke, text = ClientState.new, ClientState.corner, ClientState.stroke, ClientState.text

local DASH = GardenConfig.DASH
local PRIZE: any = GardenConfig.egg(DASH.prizeEgg)
local TOTAL = #DASH.checkpoints
local PLACES = { "1st", "2nd", "3rd", "4th", "5th", "6th" }
local HIT_COOLDOWN = 0.5
local SWEEPER_LIFT = 2 -- the bar rides above the deck, matching DashRules' hit height; the pose is on the deck
local HOW_TO = "Run and jump to the finish. Water sends you back to your last checkpoint."

-- Obstacles ---------------------------------------------------------------------------------------

type Obstacle = { o: any, model: Model, last: Vector3?, moved: Vector3, safeUntil: number }

local COLOURS = { sweeper = UI.CORAL, ball = UI.PINK, pendulum = UI.LILAC, platform = UI.MINT }
local BLOCK, BALL, CYLINDER = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

local holder: Folder? = nil
local live: { Obstacle } = {}
local platforms: { [Instance]: Obstacle } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function piece(
	model: Model,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	neon: boolean?
): Part
	return new("Part", {
		Shape = shape,
		Size = size,
		CFrame = cf,
		Color = colour,
		Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
end

-- Part-built look, centred on the model's pivot (the hinge for a pendulum). The Neon strips keep
-- obstacles readable in Moonfall (GDD T2).
local function fallback(o: any): Model
	local m = Instance.new("Model")
	local colour = (COLOURS :: any)[o.kind] or UI.PINK
	local up = CFrame.Angles(0, 0, math.pi / 2)
	if o.kind == "sweeper" then
		piece(m, BLOCK, Vector3.new(o.size * 2, 3, 3), CFrame.identity, colour)
		piece(m, BLOCK, Vector3.new(o.size * 2, 0.5, 3.2), CFrame.new(0, 1, 0), UI.WHITE, true)
		piece(m, CYLINDER, Vector3.new(7, 5, 5), CFrame.new(0, 1.5, 0) * up, UI.GOLD)
	elseif o.kind == "ball" then
		piece(m, BALL, Vector3.one * o.size * 2, CFrame.identity, colour)
		piece(m, CYLINDER, Vector3.new(0.5, o.size * 2.04, o.size * 2.04), CFrame.identity, UI.WHITE, true)
	elseif o.kind == "pendulum" then
		piece(m, BLOCK, Vector3.new(1, o.reach, 1), CFrame.new(0, -o.reach / 2, 0), UI.WHITE)
		piece(m, BALL, Vector3.one * o.size * 2, CFrame.new(0, -o.reach, 0), colour)
		piece(m, BALL, Vector3.one * 2.5, CFrame.identity, UI.GOLD, true)
	else
		piece(m, BLOCK, Vector3.new(o.size * 2, 2, o.size * 2), CFrame.identity, colour)
		piece(m, BLOCK, Vector3.new(o.size * 2 + 0.4, 0.5, o.size * 2 + 0.4), CFrame.new(0, -0.5, 0), UI.WHITE, true)
	end
	m.WorldPivot = CFrame.identity
	return m
end

-- The artist's model scaled to the config, or nil while its id is not uploaded. Hits use the config,
-- never the mesh (section 9), so a model that differs from the table still plays the same.
local function mesh(o: any): Model?
	local shared = ReplicatedStorage:FindFirstChild("NightModels")
	local template = shared and shared:FindFirstChild(o.model)
	if not (template and template:IsA("Model")) then
		return nil
	end
	local m = template:Clone()
	local _, extents = m:GetBoundingBox()
	local scale = if o.kind == "pendulum"
		then (o.reach + o.size) / extents.Y
		elseif o.kind == "sweeper" then o.size * 2 / math.max(extents.X, extents.Z)
		else o.size * 2 / extents.X
	m:ScaleTo(m:GetScale() * scale)
	if o.kind == "pendulum" then
		-- Pivots are not kept (section 9): put it back on the hinge, at the top centre.
		local _, scaled = m:GetBoundingBox()
		m.WorldPivot = m:GetPivot() * CFrame.new(0, scaled.Y / 2, 0)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return m
end

local function frame(o: any, pose: any): CFrame
	if o.kind == "sweeper" then
		return CFrame.new(pose.x, pose.y + SWEEPER_LIFT, pose.z) * CFrame.Angles(0, pose.angle, 0)
	elseif o.kind == "pendulum" then
		local swing = if o.axis == "z" then CFrame.Angles(-pose.angle, 0, 0) else CFrame.Angles(0, 0, pose.angle)
		return CFrame.new(o.at.x, o.at.y, o.at.z) * swing
	end
	return CFrame.new(pose.x, pose.y, pose.z)
end

local function buildObstacles()
	local folder = new("Folder", { Name = "DashObstacles", Parent = Workspace })
	holder = folder
	rayParams.FilterDescendantsInstances = { folder }
	for _, o in DASH.obstacles do
		local model = mesh(o) or fallback(o)
		local entry: Obstacle = { o = o, model = model, last = nil, moved = Vector3.zero, safeUntil = 0 }
		if o.kind == "platform" then
			-- One plain block is the walked surface and the carry's ray target (section 9): the mesh
			-- and the fallback are only the look, so every platform plays the same.
			new("Part", {
				Name = "Collider",
				Size = Vector3.new(o.size * 2, 2, o.size * 2),
				CFrame = model:GetPivot(),
				Transparency = 1,
				Anchored = true,
				Parent = model,
			})
			platforms[model] = entry
		end
		model.Parent = folder
		table.insert(live, entry)
	end
end

local function clearObstacles()
	if holder then
		holder:Destroy()
		holder = nil
	end
	table.clear(live)
	table.clear(platforms)
end

local myFinish: any = nil

local function hit(root: BasePart, humanoid: Humanoid, v: any)
	root.AssemblyLinearVelocity = Vector3.new(v.x, v.y, v.z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- or the walk controller cancels the push
	ClientState.sound(SFX.thud, 0.6)
	ClientState.burst(root.Position, UI.GOLD, 14, 10, 0.5)
end

RunService.Heartbeat:Connect(function()
	if #live == 0 then
		return
	end
	local now = ClientState.now()
	local clock = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local at = root and { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
	for _, entry in live do
		local o = entry.o
		local pose = DashRules.pose(o, now)
		entry.model:PivotTo(frame(o, pose))
		if o.kind == "platform" then
			local pos = Vector3.new(pose.x, pose.y, pose.z)
			entry.moved = pos - (entry.last or pos)
			entry.last = pos
		elseif root and humanoid and at and humanoid.Health > 0 and not myFinish and clock >= entry.safeUntil then
			local v = DashRules.knock(o, pose, at)
			if v then
				entry.safeUntil = clock + HIT_COOLDOWN
				hit(root, humanoid, v)
			end
		end
	end
	-- Anchored parts moved by CFrame do not carry a character, so the root takes the platform's step.
	if root then
		local below = Workspace:Raycast(root.Position, Vector3.new(0, -5, 0), rayParams)
		local entry = below and platforms[below.Instance.Parent :: Instance]
		if entry then
			root.CFrame += entry.moved
		end
	end
end)

-- HUD -----------------------------------------------------------------------------------------------

-- Drawn at the 1100 x 620 layout and scaled down to 0.6 on phones, so 30 px here stays above 18 px.
local gui = new("ScreenGui", {
	Name = "GardenDash",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local flash = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = UI.AQUA,
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})

-- Timer, place and pips take the coin bar's place (Hud hides it in a race).
local raceChip = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(440, 112),
	BackgroundColor3 = UI.CREAM,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = gui,
}, { corner(16), stroke(UI.WHITE, 3) })
ClientState.autoScale(raceChip)
local raceTime = text({
	Position = UDim2.fromOffset(16, 6),
	Size = UDim2.fromOffset(130, 56),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = raceChip,
})
local racePlace = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 14),
	Size = UDim2.fromOffset(270, 40),
	Text = "",
	TextColor3 = UI.LEAF,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = raceChip,
})
local pips: { Frame } = {}
for i = 1, TOTAL do
	pips[i] = new("Frame", {
		Position = UDim2.fromOffset(16 + (i - 1) * 40, 68),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = UI.GREY,
		Parent = raceChip,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(UI.WHITE, 2) })
end
local pipText = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 64),
	Size = UDim2.fromOffset(130, 40),
	Text = "",
	TextColor3 = UI.MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = raceChip,
})

-- Big countdown and short messages, above the middle of the screen, clear of the jump button.
local centre = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(660, 240),
	BackgroundTransparency = 1,
	Parent = gui,
})
ClientState.autoScale(centre)
local big = text({
	Size = UDim2.new(1, 0, 0, 140),
	Text = "",
	TextColor3 = UI.WHITE,
	Visible = false,
	Parent = centre,
})
new("UIStroke", { Color = UI.PINK, Thickness = 5, Parent = big })
local hint = text({
	Position = UDim2.fromOffset(0, 150),
	Size = UDim2.new(1, 0, 0, 90),
	BackgroundTransparency = 0.05,
	BackgroundColor3 = UI.CREAM,
	Text = "",
	TextScaled = false,
	TextSize = 32,
	TextWrapped = true,
	Visible = false,
	Parent = centre,
})
corner(16).Parent = hint
stroke(UI.WHITE, 3).Parent = hint
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = hint })

local sayToken = 0
local function say(headline: string, line: string, seconds: number)
	big.Text = headline
	big.Visible = headline ~= ""
	hint.Text = line
	hint.Visible = line ~= ""
	if headline ~= "" then
		ClientState.pop(big)
	end
	sayToken += 1
	local token = sayToken
	task.delay(seconds, function()
		if token == sayToken then
			big.Visible = false
			hint.Visible = false
		end
	end)
end

-- "Splash Dash starts in 12" for ready players, wherever they are; under the timers, above the jump button.
local pill = text({
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(480, 48), -- 456 px of text keeps 24 characters above 18 px at UIScale 0.6
	BackgroundTransparency = 0.05,
	BackgroundColor3 = UI.AQUA,
	TextColor3 = UI.WHITE,
	Text = "",
	Visible = false,
	Parent = gui,
})
corner(16).Parent = pill
stroke(UI.WHITE, 3).Parent = pill
new("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
	Parent = pill,
})
ClientState.autoScale(pill)
local pillScale = pill:FindFirstChildOfClass("UIScale") :: UIScale

-- Results card: no input needed, closes on tap or after 6 s (T8). No near-miss wording (G4.3).
local results = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 420),
	BackgroundColor3 = UI.CREAM,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
	Parent = gui,
}, { corner(24), stroke(UI.AQUA, 5) })
ClientState.autoScale(results)
local resultsTitle = text({
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -40, 0, 56),
	Text = "",
	TextColor3 = UI.AQUA,
	Parent = results,
})
new("UIStroke", { Color = UI.WHITE, Thickness = 3, Parent = resultsTitle })
local resultsList = new("Frame", {
	Position = UDim2.fromOffset(20, 76),
	Size = UDim2.new(1, -40, 0, 0),
	BackgroundTransparency = 1,
	Parent = results,
}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
local resultsLine = text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 20, 1, -12),
	Size = UDim2.new(1, -40, 0, 84),
	Text = "",
	TextColor3 = UI.LEAF,
	TextScaled = false,
	TextSize = 32,
	TextWrapped = true,
	Parent = results,
})
results.Activated:Connect(function()
	results.Visible = false
end)

local function seconds(t: number): string
	return string.format("%d:%04.1f", t // 60, t % 60)
end

local function resultRow(order: number, left: string, right: string)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = resultsList,
	})
	local function cell(s: string, x: number, w: number, align: Enum.TextXAlignment)
		text({
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, w, 1, 0),
			Text = s,
			TextScaled = false,
			TextSize = 34,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = align,
			Parent = r,
		})
	end
	cell(left, 0, 320, Enum.TextXAlignment.Left)
	cell(right, 320, 360, Enum.TextXAlignment.Right)
end

-- The race state ------------------------------------------------------------------------------------

local inRound = false
local roundGo = 0
local closedGo = -1 -- the round dashOver ended: a stale status must not re-enter it
local leftAt = -math.huge
local reached = 0
local firstFinish: number? = nil
local shownCount: number? = nil
local finishers: { any } = {}

local function setPips(n: number)
	reached = n
	for i, p in pips do
		p.BackgroundColor3 = if i <= n then UI.AQUA else UI.GREY
	end
	pipText.Text = `{n} / {TOTAL}`
end

local function personalLine(): string
	if myFinish == nil then
		return "Thanks for racing! Your garden kept growing."
	end
	if myFinish.egg then
		local level = GardenRules.level(ClientState.profile())
		return if level < PRIZE.level
			then `You won a {PRIZE.name}! It is saved for you. Plant it at Level {PRIZE.level}.`
			else `You won a {PRIZE.name}! Plant it from the DASH panel.`
	elseif myFinish.place == 1 then
		return if player:GetAttribute("ProfileOnline")
			then `You won! You have today's {DASH.prizesPerDay} {PRIZE.name}s, so this one goes to the next finisher.`
			else `You won! Saving is off on this server, so this {PRIZE.name} goes to the next finisher.`
	end
	local coins = tonumber(myFinish.coins) or 0
	return if coins > 0 then `Finished! +{ClientState.commas(coins)} coins` else "Finished!"
end

local function showResults(data: any)
	for _, c in resultsList:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	resultsTitle.Text = if type(data.winner) == "string" then `{data.winner} wins!` else DASH.name
	table.sort(finishers, function(a, b)
		return a.place < b.place
	end)
	for _, f in finishers do
		local prize = if f.egg
			then `  {PRIZE.name}`
			elseif (tonumber(f.coins) or 0) > 0 then `  +{ClientState.short(f.coins)} coins`
			else ""
		resultRow(f.place, `{PLACES[f.place] or f.place}  {f.name or "A racer"}`, `{seconds(f.time)}{prize}`)
	end
	if #finishers == 0 then
		resultRow(1, if data.reason == "empty" then "Round over." else "Time is up.", "No finishers this round")
	end
	resultsLine.Text = personalLine()
	results.Size = UDim2.fromOffset(720, 182 + 46 * math.max(#finishers, 1))
	results.Visible = true
	ClientState.sound(SFX.chime, 0.35, nil, 1.6)
	local shown = resultsLine.Text
	task.delay(6, function()
		if resultsLine.Text == shown then
			results.Visible = false
		end
	end)
end

local function enterRound(go: number)
	inRound = true
	roundGo = go
	myFinish = nil
	firstFinish = nil
	shownCount = nil
	finishers = {}
	setPips(0)
	racePlace.Text = ""
	results.Visible = false
	raceChip.Visible = true
	buildObstacles()
	ClientState.setRacing(true)
end

local function leaveRound()
	inRound = false
	leftAt = os.clock()
	raceChip.Visible = false
	big.Visible = false
	hint.Visible = false
	clearObstacles()
	ClientState.setRacing(false)
end

-- Distance along the course, flat, for the live place: other racers' roots replicate, their
-- checkpoints do not. shortcut: an estimate from positions, the server's finish order is the result.
local COURSE: { Vector3 } = { Vector3.new(DASH.start.x, 0, DASH.start.z) }
for _, cp in DASH.checkpoints do
	table.insert(COURSE, Vector3.new(cp.x, 0, cp.z))
end

local function progress(position: Vector3): number
	local flat = Vector3.new(position.X, 0, position.Z)
	local best, bestGap, walked = 0, math.huge, 0
	for i = 1, #COURSE - 1 do
		local a, along = COURSE[i], COURSE[i + 1] - COURSE[i]
		local length = along.Magnitude
		local k = math.clamp((flat - a):Dot(along) / (length * length), 0, 1)
		local gap = (a + along * k - flat).Magnitude
		if gap < bestGap then
			best, bestGap = walked + length * k, gap
		end
		walked += length
	end
	return best
end

local function rootOf(p: Player?): BasePart?
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function livePlace(dash: any): number
	local mine = rootOf(player)
	local rank = #finishers + 1
	if mine == nil then
		return rank
	end
	local me = progress(mine.Position)
	local finished: { [number]: boolean } = {}
	for _, f in finishers do
		finished[f.by] = true
	end
	for _, id in dash.racers do
		local other = if id ~= player.UserId and not finished[id] then rootOf(Players:GetPlayerByUserId(id)) else nil
		if other and progress(other.Position) > me then
			rank += 1
		end
	end
	return rank
end

local function countdown(dash: any, now: number)
	local go = if dash.phase == "starting" then dash.at else dash.goAt
	local left = math.ceil(go - now)
	if left < 0 or left == shownCount then
		return
	end
	shownCount = left
	if left > 3 then
		say("Get ready!", HOW_TO, 1.5)
	elseif left > 0 then
		say(tostring(left), HOW_TO, 1.5)
		ClientState.sound(SFX.tick, 0.4, nil, 1.4)
	else
		say("GO!", "", 1)
		ClientState.sound(SFX.chime, 0.4, nil, 1.8)
	end
end

local function updateRace(dash: any, now: number)
	countdown(dash, now)
	local ends = if dash.phase == "starting" then dash.at + DASH.limit else dash.at
	if firstFinish then
		ends = math.min(ends, firstFinish + DASH.grace)
	end
	raceTime.Text = ClientState.clock(ends - now)
	racePlace.Text = if myFinish
		then `Finished {PLACES[myFinish.place] or myFinish.place}`
		elseif dash.phase == "racing" then `Place {livePlace(dash)} of {#dash.racers}`
		else ""
end

local padPrompt: ProximityPrompt? = nil
local function updatePrompt(ready: boolean)
	if not (padPrompt and padPrompt.Parent) then
		local garden = Workspace:FindFirstChild("Garden")
		local course = garden and garden:FindFirstChild("Dash")
		local found = course and course:FindFirstChild("Ready", true)
		padPrompt = if found and found:IsA("ProximityPrompt") then found else nil
	end
	local prompt = padPrompt
	if prompt then
		prompt.ActionText = if ready then "Not ready" else "Ready"
		prompt.Enabled = not inRound
	end
end

local lastPhase = "idle"
local function update()
	local dash = ClientState.status().dash
	local now = ClientState.now()
	local id = player.UserId
	local go = if dash.phase == "starting" then dash.at else dash.goAt
	local racing = table.find(dash.racers, id) ~= nil and go ~= closedGo
	if racing ~= inRound then
		if racing then
			enterRound(go)
		else
			leaveRound()
		end
	end
	if inRound then
		updateRace(dash, now)
	end
	local ready = table.find(dash.ready, id) ~= nil
	updatePrompt(ready)
	pill.Visible = ready and not inRound and not ClientState.menuOpen
	if pill.Visible then
		pill.Position = UDim2.new(1, -12, 0, 20 + 128 * pillScale.Scale) -- just under Hud's 128-tall timers
		pill.Text = if dash.phase == "countdown"
			then `{DASH.name} starts in {math.max(0, math.ceil(dash.at - now))}`
			elseif dash.phase == "idle" then `{DASH.name}: {#dash.ready} / {dash.need} ready`
			else "Next race: ready"
	end
	if lastPhase == "countdown" and dash.phase == "idle" and ready then
		ClientState.toast(`{DASH.name} is waiting for {dash.need} ready players`, UI.AQUA)
	end
	lastPhase = dash.phase
end

-- Fx --------------------------------------------------------------------------------------------------

local function onSplash(data: any)
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	local cp = tonumber(data.cp) or 0
	local back = if cp > 0 then `Back to checkpoint {cp}` else "Back to the start"
	if data.reason ~= "fall" then
		say("", back, 2) -- no accusation (T7)
		return
	end
	say("SPLASH!", back, 2)
	ClientState.sound(SFX.puff, 0.6, nil, 0.7)
	if root then
		ClientState.burst(root.Position, UI.AQUA, 40, 14, 0.8)
	end
	if not GuiService.ReducedMotionEnabled then
		flash.BackgroundTransparency = 0.55
		flash.Visible = true
		local fade = TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		fade.Completed:Once(function()
			flash.Visible = false
		end)
		fade:Play()
	end
end

local function onFinish(data: any)
	table.insert(finishers, data)
	if data.place == 1 then
		firstFinish = ClientState.status().dash.goAt + (tonumber(data.time) or 0)
	end
	if data.by == player.UserId then
		myFinish = data
		setPips(TOTAL)
		say("FINISHED!", `{PLACES[data.place] or data.place} place in {seconds(data.time)}`, 3)
		ClientState.sound(SFX.fanfare, 0.5)
	end
end

local function onOver(data: any)
	local raced = inRound or os.clock() - leftAt < 2 -- the status can arrive just before the Fx
	if inRound then
		closedGo = roundGo
		leaveRound()
	end
	if raced then
		showResults(data)
	end
	finishers = {}
end

fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "dashCheckpoint" then
		setPips(tonumber(data.cp) or reached)
		say("", `Checkpoint {reached} of {tonumber(data.total) or TOTAL}`, 1.5)
		ClientState.sound(SFX.chime, 0.3, nil, 1.4 + reached * 0.1)
	elseif kind == "dashSplash" then
		onSplash(data)
	elseif kind == "dashFinish" then
		onFinish(data)
	elseif kind == "dashOver" then
		onOver(data)
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
task.spawn(function()
	while true do
		update()
		task.wait(0.1)
	end
end)
