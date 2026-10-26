--!strict
-- Neon Spire lift (GDD K4, E3): the floor picker shows while the owner stands in a lift zone of
-- their own tower (or when LIFT / GO asks for it); a ride closes the doors, sends Request("lift",
-- floor or "roof"), ticks the floor counter and opens again. The server checks the zone on its own
-- character position and teleports. A target picked away from a lift waits, with a beam to the
-- nearest lift ring, and rides as soon as the player steps into the zone.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TowerRules = require(Shared:WaitForChild("TowerRules"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer :: Player
local UI, FONT = ClientState.UI, ClientState.FONT
local new, text, button = ClientState.new, ClientState.text, ClientState.button

local gui = ClientState.gui("SpireLift", 6)
local doorsGui = ClientState.gui("SpireLiftDoors", 20, true)

-- Floor picker (bottom centre) ------------------------------------------------------------------------

local picker = ClientState.panel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, if ClientState.touch then -230 else -100),
	Size = UDim2.fromOffset(620, 128),
	Visible = false,
	Parent = gui,
})
ClientState.autoScale(picker)
local pickerTitle = text({
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -90, 0, 24),
	Text = "LIFT",
	FontFace = FONT.display,
	TextColor3 = UI.CYAN,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = picker,
})
local closePicker = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 6),
	Size = UDim2.fromOffset(56, 30),
	Text = "X",
	BackgroundColor3 = UI.MAGENTA,
	Outline = true,
	Parent = picker,
}, function() end)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 42),
	Size = UDim2.new(1, -20, 0, 76),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	Parent = picker,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

-- Doors and counter (full screen) -------------------------------------------------------------------

local left = new("Frame", {
	Position = UDim2.fromScale(-0.5, 0),
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = UI.STEEL,
	BorderSizePixel = 0,
	Parent = doorsGui,
}, {
	new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = UI.CYAN,
		BorderSizePixel = 0,
	}),
})
local right = new("Frame", {
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(0.5, 1),
	BackgroundColor3 = UI.STEEL,
	BorderSizePixel = 0,
	Parent = doorsGui,
}, { new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = UI.CYAN, BorderSizePixel = 0 }) })
local counter = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(260, 90),
	Text = "",
	FontFace = FONT.mono,
	TextColor3 = UI.CYAN,
	Visible = false,
	ZIndex = 5,
	Parent = doorsGui,
})

local function floorName(n: number, floors: number): string
	return if n == 1 then "LOBBY" elseif n > floors then "ROOF" else `FLOOR {n}`
end

-- Where the player is ---------------------------------------------------------------------------------

-- (lot-space position in the own lot, lift floor under the player or nil)
local function where(): (Vector3?, number?)
	local r = ClientState.root()
	local lot = ClientState.myLot()
	local frame = lot and ClientState.lotFrame(lot)
	if not (r and frame) then
		return nil, nil
	end
	local l = frame:PointToObjectSpace(r.Position)
	if math.abs(l.X) > 32 or math.abs(l.Z) > 46 then
		return nil, nil
	end
	return l, TowerRules.liftAt(ClientState.me(), { x = l.X, y = l.Y, z = l.Z })
end

-- Ride ------------------------------------------------------------------------------------------------

local riding = false
local pending: string? = nil
local pendingAt = 0
local manual = false

local function doors(closed: boolean, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	TweenService:Create(left, info, { Position = UDim2.fromScale(if closed then 0 else -0.5, 0) }):Play()
	TweenService:Create(right, info, { Position = UDim2.fromScale(if closed then 0.5 else 1, 0) }):Play()
end

local blur = new("BlurEffect", { Size = 0, Parent = Workspace.CurrentCamera })

local function ride(target: string)
	local _, from = where()
	if riding or not from then
		return
	end
	riding = true
	pending = nil
	manual = false
	picker.Visible = false
	GuiService.SelectedObject = nil
	local floors = #ClientState.me().floors
	local to = TowerRules.liftTarget(ClientState.me(), target) or from
	counter.Text = floorName(from, floors)
	counter.Visible = true
	doors(true, 0.6)
	TweenService:Create(blur, TweenInfo.new(0.6), { Size = 14 }):Play()
	ClientState.sound(ClientState.SFX.whoosh, 0.35, nil, 0.8)
	task.wait(0.6)
	local ok = ClientState.request("lift", target)
	if ok then
		local steps = math.abs(to - from)
		local dir = if to > from then 1 else -1
		for i = 1, steps do
			counter.Text = floorName(from + i * dir, floors)
			task.wait(math.min(0.08, 0.5 / steps))
		end
		task.wait(0.15)
	end
	counter.Visible = false
	doors(false, 0.5)
	TweenService:Create(blur, TweenInfo.new(0.5), { Size = 0 }):Play()
	task.wait(0.5)
	riding = false
end

-- Picker contents ---------------------------------------------------------------------------------------

local shownFor = ""
local function fill(current: number?)
	local p = ClientState.me()
	local floors = #p.floors
	local key = `{floors}:{current}`
	if key == shownFor then
		return
	end
	shownFor = key
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for n = 1, floors + 1 do
		local arg = if n > floors then "roof" else tostring(n)
		local b = button({
			Size = UDim2.fromOffset(if n == 1 or n > floors then 96 else 64, 64),
			Text = if n == 1 then "LOBBY" elseif n > floors then "ROOF" else tostring(n),
			BackgroundColor3 = ClientState.DEPT_COLOURS[if n <= floors then p.floors[n].d else "lobby"] or UI.CYAN,
			Outline = true,
			LayoutOrder = n,
			Parent = list,
		}, function()
			if n == current then
				return
			end
			local _, at = where()
			if at then
				task.spawn(ride, arg)
			else
				pending, pendingAt = arg, os.clock()
				picker.Visible = false
				GuiService.SelectedObject = nil
				ClientState.toast(`Step onto a lift ring: you will ride to {floorName(n, floors)}`, UI.CYAN)
			end
		end)
		ClientState.enable(b, n ~= current)
	end
end

local function openPicker()
	local _, at = where()
	manual = true
	shownFor = ""
	fill(at)
	picker.Visible = true
	if ClientState.gamepad() then
		GuiService.SelectedObject = list:FindFirstChildWhichIsA("TextButton")
	end
end

closePicker.Activated:Connect(function()
	manual = false
	picker.Visible = false
	GuiService.SelectedObject = nil
end)

ClientState.LiftRequested:Connect(function(target: string?)
	if target == nil then
		openPicker()
		return
	end
	local _, at = where()
	if at then
		task.spawn(ride, target)
	else
		pending, pendingAt = target, os.clock()
		ClientState.toast("Step onto a lift ring to ride there", UI.CYAN)
	end
end)

-- Guide beam to the nearest lift ring while a ride is pending.
local beam = new("Beam", {
	Color = ColorSequence.new(UI.CYAN),
	Width0 = 0.8,
	Width1 = 0.8,
	FaceCamera = true,
	LightEmission = 0.8,
	Enabled = false,
	Parent = Workspace.Terrain,
})
local a0 = new("Attachment", { Parent = Workspace.Terrain })
local a1 = new("Attachment", { Parent = Workspace.Terrain })
beam.Attachment0, beam.Attachment1 = a0, a1

task.spawn(function()
	local wasIn = false
	while true do
		task.wait(0.2)
		if pending and os.clock() - pendingAt > 60 then
			pending = nil
		end
		local l, at = where()
		local inZone = at ~= nil and ClientState.mode == "play" and not ClientState.menuOpen
		if inZone and pending and not riding then
			task.spawn(ride, pending :: string)
		elseif not riding then
			if inZone then
				pickerTitle.Text = `LIFT · you are on {floorName(at :: number, #ClientState.me().floors)}`
				fill(at)
				picker.Visible = true
				if not wasIn and ClientState.gamepad() and GuiService.SelectedObject == nil then
					GuiService.SelectedObject = list:FindFirstChildWhichIsA("TextButton")
				end
			elseif manual and not ClientState.menuOpen and ClientState.mode == "play" then
				pickerTitle.Text = "LIFT · pick a floor, then step onto a lift ring"
				fill(nil)
				picker.Visible = true
			else
				picker.Visible = false
				manual = false
			end
		end
		wasIn = inZone
		-- Beam from the player to the lift ring of the floor they stand on (the lobby if off the tower).
		local r = ClientState.root()
		local lot = ClientState.myLot()
		beam.Enabled = pending ~= nil and r ~= nil and lot ~= nil and not riding
		if beam.Enabled and r and lot then
			local n = 1
			if l then
				for k = #ClientState.me().floors + 1, 1, -1 do
					if l.Y >= TowerRules.floorY(k) - 1 then
						n = k
						break
					end
				end
			end
			local centre = TowerRules.liftZone(n)
			a0.WorldPosition = r.Position - Vector3.new(0, 2, 0)
			a1.WorldPosition = ClientState.toWorld(lot, { x = centre.x, y = centre.y + 1, z = centre.z }) or r.Position
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
doorsGui.Parent = player:WaitForChild("PlayerGui")
