--!strict
-- Lantern Express HUD (GDD H2, F, J, L; architecture lantern 6): lantern meter, phase chip with a
-- calm progress bar (never a countdown number), coal bar with tonight's need, Parts and oil,
-- Tickets and the level ring, carry slots and DROP, seat buttons, the crew list with role badges and
-- pings, the Depot panel (upgrades, branch and weekly votes), the rescue reveal, the run end card and
-- every toast. Display and requests only: the server decides every outcome.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DepotRules = require(Shared:WaitForChild("DepotRules"))
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local TrainRules = require(Shared:WaitForChild("TrainRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState")) -- configures the kit first
local UiKit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))

local UI = ClientState.UI
local new = UiKit.new
local player = Players.LocalPlayer

local gui = new("ScreenGui", {
	Name = "LanternHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
UiKit.scaleRoot(gui)
local hud = new("Frame", { Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local toast = UiKit.toast(gui)
ClientState.Toasted:Connect(function(text: string, icon: string?, colour: Color3?)
	toast(text, icon, colour)
end)

local function setBar(back: Frame, fraction: number, colour: Color3?)
	local fill = back:FindFirstChildOfClass("Frame") :: Frame
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if colour then
		fill.BackgroundColor3 = colour
	end
end

-- A "+N" that rises and fades over a chip (skipped under Reduced Motion).
local function float(over: GuiObject, s: string)
	if ClientState.still() then
		return
	end
	local f = UiKit.text(over, s, 24, UI.GOLD, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(120, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		Outline = UI.INK,
		OutlineThickness = 1.5,
		ZIndex = 6,
	})
	TweenService:Create(f, TweenInfo.new(0.9), { Position = UDim2.new(1, -8, 0, -36), TextTransparency = 1 }):Play()
	task.delay(0.95, f.Destroy, f)
end

-- Top left: coal (tonight's need marked), Parts and oil "for this run" ------------------------------

local left = new("Frame", {
	Name = "Pools",
	Position = UDim2.fromOffset(24, 20),
	Size = UDim2.fromOffset(380, 130),
	BackgroundTransparency = 1,
	Parent = hud,
})
local coalChip = UiKit.chip(left, 380, 76)
UiKit.icon(coalChip, "coal", 40, { Position = UDim2.fromOffset(10, 8) })
local coalText =
	UiKit.chipText(coalChip, "Coal", { Position = UDim2.fromOffset(58, 4), Size = UDim2.new(1, -66, 0, 30) })
local coalBar =
	UiKit.bar(coalChip, { Position = UDim2.fromOffset(58, 40), Size = UDim2.new(1, -72, 0, 14) }, 0, UI.GOLD)
local needMark = new("Frame", {
	Name = "Tonight",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(4, 24),
	BackgroundColor3 = UI.CREAM,
	ZIndex = 3,
	Parent = coalBar,
})
local needText = UiKit.chipText(coalChip, "", {
	Position = UDim2.fromOffset(58, 54),
	Size = UDim2.new(1, -66, 0, 20),
	TextSize = 16,
})
local poolChip = UiKit.chip(left, 380, 44)
poolChip.Position = UDim2.fromOffset(0, 86)
UiKit.icon(poolChip, "parts", 32, { Position = UDim2.fromOffset(10, 6) })
local poolText = UiKit.chipText(poolChip, "", { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -58, 1, 0) })

-- Top centre: the lantern meter and the phase chip ---------------------------------------------------

local centre = new("Frame", {
	Name = "Run",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(460, 150),
	BackgroundTransparency = 1,
	Parent = hud,
})
local lampChip = UiKit.chip(centre, 460, 60)
local lampIcon = new("Frame", {
	Name = "Lantern",
	Position = UDim2.fromOffset(10, 6),
	Size = UDim2.fromOffset(36, 48),
	BackgroundColor3 = UI.GOLD,
	Parent = lampChip,
}, { new("UICorner", { CornerRadius = UDim.new(0.45, 0) }), new("UIStroke", { Color = UI.RING, Thickness = 2 }) })
UiKit.icon(lampIcon, "lantern", 44, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
local lampBar =
	UiKit.bar(lampChip, { Position = UDim2.fromOffset(58, 20), Size = UDim2.new(1, -150, 0, 20) }, 1, UI.GOLD)
local lampText = UiKit.chipText(lampChip, "100", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 0),
	Size = UDim2.fromOffset(76, 60),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextSize = 26,
})
local phaseChip = UiKit.chip(centre, 460, 70)
phaseChip.Position = UDim2.fromOffset(0, 70)
local phaseText =
	UiKit.chipText(phaseChip, "", { Size = UDim2.new(1, -24, 0, 38), TextXAlignment = Enum.TextXAlignment.Center })
-- The calm bar: ride progress, the stop's calm time, the fog, the night or the departure (G3.6).
local phaseBar =
	UiKit.bar(phaseChip, { Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 12) }, 0, UI.RING)

-- Top right: Tickets and the level ring --------------------------------------------------------------

local right = new("Frame", {
	Name = "Meta",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 0),
	Size = UDim2.fromOffset(600, 100),
	BackgroundTransparency = 1,
	Parent = hud,
})
local coins = UiKit.coinPill(right)
local ring = UiKit.levelRing(right)

-- A narrow screen (a phone at the kit's 0.6 floor): the lantern meter and phase chip drop below the
-- Tickets pill instead of overlapping it.
local function fit()
	local scale = gui:FindFirstChild("KitScale") :: UIScale
	local width = gui.AbsoluteSize.X / math.max(scale.Scale, 0.01)
	centre.Position = UDim2.new(0.5, 0, 0, if width / 2 + 230 > width - 600 then 104 else 16)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- QA M4: while the server cannot save (ProfileOnline false), say so for as long as it lasts; the
-- server's notice says why, and that everything earned is kept until it can.
local paused = UiKit.chip(hud, 300, 40)
paused.Name = "SavingPaused"
paused.AnchorPoint = Vector2.new(1, 0)
paused.Position = UDim2.new(1, -16, 0, 108)
UiKit.chipText(paused, "Saving paused", {
	TextColor3 = UI.CORAL,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 17,
})
local function showPaused()
	paused.Visible = player:GetAttribute("ProfileOnline") == false
end
player:GetAttributeChangedSignal("ProfileOnline"):Connect(showPaused)
showPaused()

-- Bottom centre: carry slots and DROP ----------------------------------------------------------------

local carry = new("Frame", {
	Name = "Carry",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(420, 84),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = hud,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local KIND_NAME = { coal = "Coal", parts = "Parts", oil = "Oil", supply = "Supply", critter = "Critter" }
local function kindOf(entry: any): string
	if type(entry) == "string" then
		return entry
	elseif type(entry) == "table" and type(entry.kind) == "string" then
		return entry.kind
	end
	return "item"
end
local function onDrop()
	ClientState.request("drop")
end
local dropButton = UiKit.button(carry, "DROP", UI.CORAL, "small", 110, onDrop)
dropButton.LayoutOrder = 10

local function drawCarry()
	for _, c in carry:GetChildren() do
		if c:IsA("Frame") and c.Name == "Slot" then
			c:Destroy()
		end
	end
	-- The server's shape (architecture lantern 5): { small = { kinds }, big = kind?, help = itemId? };
	-- a helper holds the other end of a critter crate.
	local data = ClientState.json(player:GetAttribute("Carry")) or {}
	local big = data.big ~= nil or data.help ~= nil
	local list: { string } = {}
	if big then
		list = { kindOf(data.big or "critter") }
	else
		for _, e in data.small or {} do
			table.insert(list, kindOf(e))
		end
	end
	carry.Visible = #list > 0
	for i = 1, if big then 1 else 3 do
		local slot = UiKit.chip(carry, if big then 200 else 72, 72)
		slot.Name = "Slot"
		slot.LayoutOrder = i
		local kind = list[i]
		if kind then
			UiKit.icon(slot, kind, 40, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4) })
			UiKit.chipText(slot, KIND_NAME[kind] or "Item", {
				Position = UDim2.new(0, 2, 1, -26),
				Size = UDim2.new(1, -4, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 16,
			})
		end
	end
end
-- QA m3: "Help carry" means nothing to a player whose hands are full (their own crate included):
-- hidden on this client only, by distance (the server owns Enabled); the server checks every press.
local hiddenHelp: { [ProximityPrompt]: number } = {}
local function handsFull(): boolean
	local data = ClientState.json(player:GetAttribute("Carry")) or {}
	return data.big ~= nil or data.help ~= nil or #(data.small or {}) > 0
end
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "Help" and handsFull() then
		hiddenHelp[prompt] = hiddenHelp[prompt] or prompt.MaxActivationDistance
		prompt.MaxActivationDistance = 0
	end
end)
player:GetAttributeChangedSignal("Carry"):Connect(function()
	drawCarry()
	if not handsFull() then
		for prompt, distance in hiddenHelp do
			prompt.MaxActivationDistance = distance
		end
		hiddenHelp = {}
	end
end)
drawCarry()

-- Right side: seat buttons ------------------------------------------------------------------------------

local seats = new("Frame", {
	Name = "Seat",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.55, 0),
	Size = UDim2.fromOffset(220, 300),
	BackgroundTransparency = 1,
	Parent = hud,
}, {
	new("UIListLayout", {
		Padding = UDim.new(0, 18),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local openDepot: () -> ()
local stokeUntil = 0
local stoked = false
local function onStoke()
	if ClientState.request("stoke") then
		stoked = true -- the "Tap to stoke!" hint has done its job
		stokeUntil = os.clock() + LanternConfig.STOKE.cooldown
		ClientState.sound("chuff", 0.6)
	end
end
local function onMend()
	if ClientState.request("mend") then
		ClientState.sound("glug", 0.6)
	end
end
local function onSit()
	ClientState.request("sit", "any")
end
local function onStand()
	ClientState.request("stand")
end
-- While moving: a lamp turret at night, back to the Stoker seat from a turret (a solo crew must
-- reach a lamp at night; the server re-seats, it never stops the train).
local function onSwap()
	ClientState.request("sit", if player:GetAttribute("Seat") == "turret" then "stoker" else "turret")
end
local stoke = UiKit.button(seats, "STOKE", UI.GOLD, "large", 220, onStoke)
local mend = UiKit.button(seats, "MEND", UI.LEAF, "large", 220, onMend)
local sit = UiKit.button(seats, "SIT", UI.AQUA, "medium", 200, onSit)
local stand = UiKit.button(seats, "STAND", UI.INK_SOFT, "medium", 200, onStand)
local depotButton = UiKit.button(seats, "DEPOT", UI.GOLD, "medium", 200, function()
	openDepot()
end)
local swap = UiKit.button(seats, "LAMP", UI.LILAC, "medium", 200, onSwap)
UiKit.buttonIcon(stoke, "stoke", 44)
UiKit.buttonIcon(mend, "mend", 44)
UiKit.buttonIcon(sit, "train")
UiKit.buttonIcon(depotButton, "depot")
local swapLamp, swapStoke = UiKit.buttonIcon(swap, "lamp"), UiKit.buttonIcon(swap, "stoke")
local pulse = new("UIScale", { Parent = stoke })
local stokeTween = TweenService:Create(
	pulse,
	TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Scale = 1.08 }
)
local stokeHint = UiKit.text(stoke, "Tap to stoke!", 20, UI.CREAM, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -4),
	Size = UDim2.fromOffset(220, 26),
	Outline = UI.INK,
	OutlineThickness = 1.5,
})

-- Gamepad buttons (QA m8) and two keys for the turret, where the PC mouse is locked to the centre (QA
-- m7: F swaps seat, R stokes or mends). A bind presses the first of its buttons that shows and is
-- enabled; each button shows its gamepad glyph or key.
local GAMEPAD = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}
local badges: { { glyph: ImageLabel, key: TextLabel? } } = {}
local function bind(name: string, pad: Enum.KeyCode, key: Enum.KeyCode?, targets: { { any } })
	ContextActionService:BindAction(name, function(_, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin or not hud.Visible then
			return Enum.ContextActionResult.Pass
		end
		for _, p in targets do
			local b = p[1] :: TextButton
			if b.Visible and b:GetAttribute("Disabled") ~= true then
				p[2]()
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(if key then { pad, key } else { pad })) -- a nil hotkey is an error
	for _, p in targets do
		local glyph = new("ImageLabel", {
			Name = "Glyph",
			Image = UserInputService:GetImageForKeyCode(pad),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = p[1],
		})
		local letter = if key
			then UiKit.text(p[1], key.Name, 18, UI.INK, {
				Name = "Key",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.fromOffset(30, 30),
				BackgroundTransparency = 0,
				BackgroundColor3 = UI.CREAM,
				ZIndex = 8,
			})
			else nil
		table.insert(badges, { glyph = glyph, key = letter })
	end
end
bind("LanternSeat", Enum.KeyCode.ButtonY, nil, { { sit, onSit }, { stand, onStand } })
bind("LanternDrop", Enum.KeyCode.ButtonB, nil, { { dropButton, onDrop } })
bind("LanternWork", Enum.KeyCode.ButtonR1, Enum.KeyCode.R, { { stoke, onStoke }, { mend, onMend } })
bind("LanternSwap", Enum.KeyCode.DPadUp, Enum.KeyCode.F, { { swap, onSwap } })
bind("LanternDepot", Enum.KeyCode.DPadDown, nil, {
	{
		depotButton,
		function()
			openDepot() -- assigned further down
		end,
	},
})
local function showBadges()
	local last = UserInputService:GetLastInputType()
	local pad = GAMEPAD[last] == true
	local keys = last == Enum.UserInputType.Keyboard
		or last == Enum.UserInputType.MouseMovement
		or string.find(last.Name, "MouseButton") ~= nil
	for _, b in badges do
		b.glyph.Visible = pad
		if b.key then
			b.key.Visible = keys
		end
	end
end
UserInputService.LastInputTypeChanged:Connect(showBadges)
showBadges()

-- Left: the crew list ------------------------------------------------------------------------------------

local crewList = new("Frame", {
	Name = "Crew",
	Position = UDim2.fromOffset(24, 170),
	Size = UDim2.fromOffset(330, 300),
	BackgroundTransparency = 1,
	Parent = hud,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
local ROLE_NAME = { stoker = "Stoker", lamplighter = "Lamplighter", scout = "Scout", mender = "Mender" }
local SEAT_NAME = { stoker = "Stoker", turret = "Lamp", mender = "Mender", passenger = "Riding", [""] = "Standing" }
local pings: { [number]: { id: string, at: number } } = {}

local function drawCrew(r: ClientState.Run)
	for _, c in crewList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, m in r.Crew do
		local p = Players:GetPlayerByUserId(m.userId)
		local row = UiKit.chip(crewList, 330, 44)
		row.LayoutOrder = i
		local badge = p and p:GetAttribute("Badge")
		local x = 10
		if type(badge) == "string" and ROLE_NAME[badge] then
			UiKit.icon(row, badge, 32, { Position = UDim2.fromOffset(8, 6) })
			x = 46
		end
		local name = if p then p.DisplayName else "Crew"
		local conductor = r.Conductor == m.userId
		UiKit.chipText(row, `{name} · {SEAT_NAME[m.seat or ""] or "Riding"}`, {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(1, -x - 50, 1, 0),
			TextColor3 = if conductor then UI.GOLD else nil,
			TextSize = 17,
		})
		local ping = pings[m.userId]
		if ping and os.clock() - ping.at < 8 then
			UiKit.icon(row, ping.id, 32, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6) })
		end
	end
end
ClientState.Pinged:Connect(function(userId: number, id: string)
	pings[userId] = { id = id, at = os.clock() }
	drawCrew(ClientState.run())
	task.delay(8.1, function()
		drawCrew(ClientState.run())
	end)
end)

-- Phase text and the calm bar --------------------------------------------------------------------------

local function tileName(r: ClientState.Run): string
	local t = LanternConfig.tile(r.Tile or "")
	return if t then t.name else "the next stop"
end

local function track(r: ClientState.Run): LanternConfig.Track
	return LanternConfig.TRACKS[ClientState.trackName(r)]
end

-- (text, bar fraction, bar colour, chip red) for the phase.
local function phaseLine(r: ClientState.Run, now: number): (string, number, Color3, boolean)
	local stops = #track(r).stops
	if r.Phase == "ride" then
		local t = track(r)
		local to = t.stops[r.Stop or 1] or t.finish
		local from = if (r.Stop or 1) > 1 then t.stops[(r.Stop or 1) - 1] else 0
		return `Next: Stop {r.Stop} of {stops} · {tileName(r)}`,
			((r.D or 0) - from) / math.max(1, to - from),
			UI.RING,
			false
	elseif r.Phase == "stop" then
		local bell = if (r.BellAt or 0) > 0 then r.BellAt else (r.PhaseAt or now) + LanternConfig.STOP.calm
		if now < bell then
			return `Stop {r.Stop} of {stops} · {tileName(r)} · Scavenge!`,
				(now - (r.PhaseAt or now)) / LanternConfig.STOP.calm,
				UI.RING,
				false
		end
		local front = TrainRules.fogFront({ phase = "stop", bellAt = bell } :: any, now) or 0
		return "Fog bell! Back to the train", front / LanternConfig.STOP.depth, UI.FOG, true
	elseif r.Phase == "night" then
		local t = track(r)
		local text = `Night · wave {r.Wave or 0}`
		return text, ((r.D or 0) - t.nightFrom) / math.max(1, t.finish - t.nightFrom), UI.SKY, false
	elseif r.Phase == "depot" then
		local leave = r.LeaveAt or 0
		local f = if leave > 0 then (now - (r.PhaseAt or now)) / math.max(1, leave - (r.PhaseAt or now)) else 0
		return "Depot · leaving when all aboard", f, UI.GOLD, false
	elseif r.Phase == "ended" then
		return "Back to Lamplight Depot", 1, UI.GOLD, false
	end
	local leave = r.LeaveAt or 0
	local f = if leave > 0 then (now - (r.PhaseAt or now)) / math.max(1, leave - (r.PhaseAt or now)) else 0
	return if ClientState.inCrew() then "Lamplight Depot · all aboard!" else "Lamplight Depot", f, UI.GOLD, false
end

-- Refresh ----------------------------------------------------------------------------------------------------

local lastCoal, lastParts = -1, -1
local function refresh()
	local r = ClientState.run()
	local now = ClientState.now()
	local cap = math.max(1, r.CoalCap or 80)
	local coal = math.floor(r.Coal or 0)
	local need = math.ceil(r.CoalNeed or 0)
	coalText.Text = `Coal {coal} / {cap}`
	setBar(coalBar, coal / cap, if coal <= LanternConfig.COAL_LOW then UI.CORAL else UI.GOLD)
	needMark.Visible = need > 0 and r.Phase ~= "hub"
	needMark.Position = UDim2.fromScale(math.clamp(need / cap, 0, 1), 0.5)
	needText.Text = if need > 0 and r.Phase ~= "hub"
		then `Tonight: {coal} / {need}`
		elseif r.Phase == "hub" then "Full bunker for the run"
		else ""
	needText.TextColor3 = if coal < need then UI.PINK else UI.CHIP_TEXT
	local parts = math.floor(r.Parts or 0)
	poolText.Text = `Parts {parts} · Oil {math.floor(r.Oil or 0)} / {LanternConfig.LANTERN.store} · for this run`
	if lastCoal >= 0 and coal > lastCoal then
		float(coalChip, `+{coal - lastCoal}`)
	end
	if lastParts >= 0 and parts > lastParts then
		float(poolChip, `+{parts - lastParts}`)
	end
	lastCoal, lastParts = coal, parts

	local lantern = math.clamp(r.Lantern or 100, 0, 100)
	setBar(lampBar, lantern / 100, if lantern < 25 then UI.CORAL else UI.GOLD)
	lampText.Text = tostring(math.floor(lantern))
	lampIcon.BackgroundTransparency = 0.7 * (1 - lantern / 100)

	local text, f, colour, red = phaseLine(r, now)
	phaseText.Text = text
	setBar(phaseBar, f, colour)
	phaseChip.BackgroundColor3 = if red then UI.CORAL else UI.CHIP

	local seat = player:GetAttribute("Seat")
	local crew = ClientState.inCrew()
	local moving = (r.Speed or 0) > 0.1
	stoke.Visible = seat == "stoker"
	UiKit.setEnabled(stoke, moving and os.clock() >= stokeUntil and (r.Coal or 0) >= LanternConfig.STOKE.coal)
	local hint = seat == "stoker" and moving and not stoked and not ClientState.still()
	stokeHint.Visible = seat == "stoker" and moving and not stoked
	if hint and stokeTween.PlaybackState ~= Enum.PlaybackState.Playing then
		stokeTween:Play()
	elseif not hint and stokeTween.PlaybackState == Enum.PlaybackState.Playing then
		stokeTween:Cancel()
		pulse.Scale = 1
	end
	mend.Visible = seat == "mender"
	UiKit.setEnabled(mend, (r.Oil or 0) >= 1 and lantern <= LanternConfig.LANTERN.mendMax)
	local seated = type(seat) == "string" and seat ~= ""
	sit.Visible = crew and not seated and not moving and r.Phase ~= "ended"
	stand.Visible = crew and seated and not moving and (r.Phase == "stop" or r.Phase == "depot" or r.Phase == "hub")
	depotButton.Visible = crew and (r.Phase == "depot" or r.Phase == "hub") and UiKit.current() == nil
	depotButton.Text = if r.Phase == "hub" then "VOTE" else "DEPOT"
	swap.Visible = crew and seated and moving and (seat == "turret" or r.Phase == "night")
	swap.Text = if seat == "turret" then "STOKER" else "LAMP"
	swapLamp.Visible, swapStoke.Visible = seat ~= "turret", seat == "turret"

	coins.set(player:GetAttribute("Tickets") or 0)
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local lo, hi = MetaRules.xpForLevel(level), MetaRules.xpForLevel(level + 1)
	ring.set(level, (xp - lo) / math.max(1, hi - lo), `{ClientState.short(xp - lo)} / {ClientState.short(hi - lo)} XP`)
end
task.spawn(function()
	while true do
		refresh()
		task.wait(0.2)
	end
end)
ClientState.RunChanged:Connect(function(name: string)
	if name == "Crew" or name == "Conductor" then
		drawCrew(ClientState.run())
	end
end)
drawCrew(ClientState.run())
local lastTickets = player:GetAttribute("Tickets") or 0
player:GetAttributeChangedSignal("Tickets"):Connect(function()
	local t = player:GetAttribute("Tickets") or 0
	coins.gain(t - lastTickets)
	lastTickets = t
end)

hud.Visible = not ClientState.menuOpen
ClientState.MenuChanged:Connect(function(open: boolean)
	hud.Visible = not open
end)

-- The Depot panel (GDD F; architecture 11.7: upgrades in phase depot, the weekly vote in the hub) --------

local VOTES = {
	depot = {
		{ id = "forest", title = "FOREST LINE", line = "More coal, gentler nights", colour = UI.MINT },
		{ id = "lake", title = "LAKE LINE", line = "Rarer critters, one more wisp a wave", colour = UI.AQUA },
	},
	hub = {
		{ id = "free", title = "FREE RUN", line = "A new valley every run", colour = UI.GOLD },
		{
			id = "weekly",
			title = "LINE OF THE WEEK",
			line = "The same stops for everyone: the weekly board",
			colour = UI.LILAC,
		},
	},
}
local ROMAN = { "I", "II", "III" }
local ICON = { boiler = "train", bunker = "coal", lamps = "lamp", coal = "coal", oil = "oil" }
local panel: UiKit.Panel? = nil

local function fillDepot(p: UiKit.Panel)
	local r = ClientState.run()
	for _, c in p.body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local order = 0
	local function heading(s: string)
		order += 1
		UiKit.text(p.body, s, 24, UI.INK, { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left })
	end
	if r.Phase == "depot" then
		heading(`Parts for this run: {math.floor(r.Parts or 0)}`)
		local pools = {
			parts = r.Parts or 0,
			coal = r.Coal or 0,
			oil = r.Oil or 0,
			levels = { boiler = r.Boiler or 1, bunker = r.Bunker or 1, lamps = r.Lamps or 1 },
		}
		local EFFECT = {
			boiler = "Cruise 20 / 23 / 26 studs a second",
			bunker = "Coal bunker 80 / 100 / 120",
			lamps = "Faster puffs, longer beams",
			coal = `{LanternConfig.COAL_BUY.coal} coal into the bunker`,
			oil = `{LanternConfig.OIL_BUY.cans} oil cans for the store`,
		}
		local items = {}
		for _, u in LanternConfig.UPGRADES do
			local level = (pools.levels :: any)[u.id] or 1 -- the card names the level it buys
			table.insert(items, { id = u.id, name = `{u.name} {ROMAN[math.min(level + 1, 3)]}` })
		end
		table.insert(items, { id = "coal", name = "Coal" })
		table.insert(items, { id = "oil", name = "Oil" })
		for _, it in items do
			order += 1
			local row = UiKit.row(p.body, 76, order)
			UiKit.icon(row, ICON[it.id], 52, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) })
			UiKit.text(row, it.name, 26, UI.INK, {
				Position = UDim2.fromOffset(80, 6),
				Size = UDim2.new(1, -320, 0, 34),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			UiKit.text(row, EFFECT[it.id], 18, UI.INK_SOFT, {
				Position = UDim2.fromOffset(80, 40),
				Size = UDim2.new(1, -320, 0, 26),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			local price = DepotRules.price(pools :: any, it.id)
			local label = if price
				then `{price} Parts`
				else (if it.id == "coal" or it.id == "oil" then "FULL" else "MAX")
			local b = UiKit.button(row, label, UI.GOLD, "small", 200, function()
				ClientState.request("buy", it.id)
			end)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -20, 0.5, -3)
			UiKit.setEnabled(b, price ~= nil and price <= pools.parts)
		end
	end
	local options = if r.Phase == "hub" then VOTES.hub elseif (r.Leg or 1) < 3 then VOTES.depot else nil
	if options then
		heading(if r.Phase == "hub" then "This run: free or the Line of the Week?" else "Next leg: pick a line")
		order += 1
		local holder = new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, LayoutOrder = order, Parent = p.body },
			{
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 20),
				}),
			}
		)
		for _, o in options do
			local card =
				new("Frame", { Size = UDim2.fromOffset(360, 146), BackgroundTransparency = 1, Parent = holder })
			local b = UiKit.button(card, o.title, o.colour, "large", 360, function()
				ClientState.request("vote", o.id)
			end)
			b.Position = UDim2.fromOffset(0, 0)
			local votes = tonumber(r.Votes[o.id]) or 0
			UiKit.text(card, `{o.line} · {votes} vote{if votes == 1 then "" else "s"}`, 18, UI.INK, {
				Position = UDim2.fromOffset(0, 80),
				Size = UDim2.new(1, 0, 0, 56),
				TextWrapped = true,
			})
		end
	end
end

function openDepot()
	local r = ClientState.run()
	if not (r.Phase == "depot" or r.Phase == "hub") then
		return
	end
	local p = UiKit.panel(gui, if r.Phase == "hub" then "ALL ABOARD" else "DEPOT", UI.GOLD)
	panel = p
	p.onClose = function()
		if panel == p then
			panel = nil
		end
	end
	fillDepot(p)
	UiKit.selectFirst(p.frame)
end

ClientState.RunChanged:Connect(function(name: string)
	local r = ClientState.run()
	if name == "Phase" and r.Phase == "depot" and ClientState.inCrew() and not ClientState.menuOpen then
		openDepot()
	elseif name == "Phase" and panel then
		panel.close()
	elseif
		panel and (name == "Parts" or name == "Votes" or name == "Boiler" or name == "Bunker" or name == "Lamps")
	then
		fillDepot(panel)
	end
end)

-- Rescue reveal, run end card and Fx toasts ---------------------------------------------------------------

local CHIMES = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
local newSpecies: { [string]: boolean } = {}

local function reveal(species: string, by: number?)
	local rarity = ClientState.rarityOf(species)
	local isNew = newSpecies[species] == true
	newSpecies[species] = nil
	local m = UiKit.modal(gui, if isNew then "NEW!" else "RESCUED!", ClientState.rarityColour(species), 440, 400, false)
	local view = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, Parent = m.body })
	UiKit.viewport(view, species)
	UiKit.text(m.body, `{ClientState.critterName(species)} ({ClientState.rarityName(species)})`, 28, UI.INK, {
		LayoutOrder = 1,
	})
	local who = by and Players:GetPlayerByUserId(by)
	UiKit.text(m.body, if who then `Brought home by {who.DisplayName}` else "Safe on the train", 18, UI.INK_SOFT, {
		LayoutOrder = 2,
	})
	-- C7: tiers sound different (one soft chime for common up to five for legendary; no slot sounds)
	for i = 1, CHIMES[rarity] or 1 do
		task.delay((i - 1) * 0.18, ClientState.sound, "chime", 0.35, nil, 1.1 + 0.12 * i)
	end
	task.delay(3, m.close)
end

local REASON = {
	dawn = "You reached Dawn Station!",
	coal = "The train ran out of coal, so the crew walked home.",
	lantern = "The lantern went out, so the crew rode home.",
	empty = "The crew went home.",
}
local function runEnd(data: any)
	local s = if type(data.summary) == "table" then data.summary else {}
	local m = UiKit.modal(gui, "RUN COMPLETE", UI.GOLD, 620, 420)
	local critters = tonumber(s.critters) or 0
	local tickets = tonumber(s.tickets) or 0
	UiKit.text(
		m.body,
		`You rescued {critters} critter{if critters == 1 then "" else "s"} and earned {ClientState.short(tickets)} Tickets`,
		28,
		UI.INK,
		{
			Size = UDim2.new(1, 0, 0, 80),
			TextWrapped = true,
			LayoutOrder = 1,
		}
	)
	if tonumber(s.xp) then
		local line = UiKit.text(m.body, `+{ClientState.short(s.xp)} XP`, 24, UI.LEAF, { LayoutOrder = 2 })
		UiKit.icon(line, "xp", 36, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -60, 0.5, 0) })
	end
	UiKit.text(
		m.body,
		REASON[data.reason] or "",
		22,
		UI.INK_SOFT,
		{ LayoutOrder = 3, TextWrapped = true, Size = UDim2.new(1, 0, 0, 60) }
	)
	-- QA M4: never "saved" while the server cannot save
	local saved = player:GetAttribute("ProfileOnline") ~= false
	UiKit.text(
		m.body,
		if saved then "Everything you earned is saved." else "Saving is paused, so this run is not in your save yet.",
		20,
		if saved then UI.INK_SOFT else UI.CORAL,
		{ LayoutOrder = 4, TextWrapped = true, Size = UDim2.new(1, 0, 0, 50) }
	)
	task.delay(LanternConfig.END_CARD, m.close)
end

local KIND_TEXT = { coal = "coal", parts = "Parts", oil = "oil", supply = "supplies", critter = "a critter" }
ClientState.Fx.OnClientEvent:Connect(function(kind: string, data: any)
	if type(data) ~= "table" then
		data = {}
	end
	if kind == "new" and type(data.species) == "string" then
		newSpecies[data.species] = true
	elseif kind == "rescue" and type(data.species) == "string" then
		task.delay(0.1, reveal, data.species, tonumber(data.by)) -- after this player's `new`, if any
	elseif kind == "payout" then
		if type(data.text) == "string" and data.text ~= "" then
			toast(data.text, "ticket", UI.GOLD)
		end
	elseif kind == "notice" and type(data.text) == "string" then
		toast(data.text, "notice", UI.LILAC)
	elseif kind == "announce" and type(data.species) == "string" then
		local rarity = string.upper(ClientState.rarityName(data.species))
		toast(
			`{tostring(data.name)} rescued a {rarity} {ClientState.critterName(data.species)}!`,
			"album",
			ClientState.rarityColour(data.species)
		)
	elseif kind == "buy" then
		local who = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		local u = nil
		for _, row in LanternConfig.UPGRADES do
			if row.id == data.id then
				u = row
			end
		end
		local what = if u
			then `{u.name} {ROMAN[tonumber(data.level) or 1] or ""}`
			else (KIND_TEXT[data.id] or tostring(data.id))
		toast(`{if who then who.DisplayName else "Crew"}: {what}`, "parts", UI.GOLD)
	elseif kind == "arrive" and data.phase == "depot" then -- QA m2: the Depot is not a stop
		toast("Depot: spend Parts, vote the next line", "depot", UI.GOLD)
	elseif kind == "arrive" then
		toast(`Scavenge! {tileName(ClientState.run())}`, "critter", UI.MINT)
	elseif kind == "runEnd" then
		runEnd(data)
	elseif kind == "load" and tonumber(data.by) == player.UserId and data.kind ~= "critter" then
		ClientState.sound("tick", 0.2, nil, 1.6)
	end
end)
