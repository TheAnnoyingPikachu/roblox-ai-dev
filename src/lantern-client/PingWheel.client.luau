--!strict
-- Lantern Express ping wheel (GDD I2; architecture lantern 6): hold Q or the left bumper, or tap the
-- PING button, and pick one of six phrases. The client sends only `ping <id>` or
-- `ping <id>:<itemId>` for the item under the cursor (or the screen centre); the server places it.
-- Markers come from Fx ping: the phrase and the sender's name for 8 s, at most 3 per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("UiKit"))

local UI = ClientState.UI
local new = UiKit.new
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local COLOUR =
	{ coal = UI.GOLD, critter = UI.MINT, help = UI.CORAL, back = UI.AQUA, wisps = UI.LILAC, thanks = UI.PINK }

local gui = new("ScreenGui", {
	Name = "LanternPing",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 3,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
UiKit.scaleRoot(gui)

local wheel = new("Frame", {
	Name = "Wheel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 420),
	BackgroundTransparency = 1,
	Visible = false,
	SelectionGroup = true,
	Parent = gui,
})
local hub = UiKit.chip(wheel, 96, 96)
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
UiKit.chipText(hub, "PING", { TextXAlignment = Enum.TextXAlignment.Center })

local slices: { { id: string, button: TextButton, angle: number } } = {}
local chosen: string? = nil
local readyAt = 0

-- The item the player looks at: a model with an ItemId attribute (set by the server's Stops).
local function lookedAtItem(): number?
	local at = if UserInputService.MouseEnabled and not UserInputService.TouchEnabled
		then UserInputService:GetMouseLocation()
		else camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(at.X, at.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Instance }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 80, params)
	local node: Instance? = hit and hit.Instance
	while node and node ~= Workspace do
		local id = node:GetAttribute("ItemId")
		if type(id) == "number" then
			return id
		end
		node = node.Parent
	end
	return nil
end

local function close()
	wheel.Visible = false
	ClientState.wheelOpen = false
	chosen = nil
end

local function send(id: string)
	close()
	if os.clock() < readyAt then
		return
	end
	readyAt = os.clock() + 2 -- one ping per 2 s (the server's rule; avoids a refusal)
	local item = if id == "coal" or id == "critter" or id == "help" then lookedAtItem() else nil
	ClientState.request("ping", if item then `{id}:{item}` else id)
end

for i, p in LanternConfig.PINGS do
	local angle = math.rad(-90 + (i - 1) * 60)
	local b = UiKit.button(wheel, p.text, COLOUR[p.id] or UI.GOLD, "small", 190, function()
		send(p.id)
	end)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, math.cos(angle) * 170, 0.5, math.sin(angle) * 150)
	table.insert(slices, { id = p.id, button = b, angle = angle })
end

local function highlight(dir: Vector2)
	if dir.Magnitude < 0.3 then
		chosen = nil
	else
		local a = math.atan2(dir.Y, dir.X)
		local best, bestD = nil, math.huge
		for _, s in slices do
			local d = math.abs((a - s.angle + math.pi) % (2 * math.pi) - math.pi)
			if d < bestD then
				best, bestD = s.id, d
			end
		end
		chosen = best
	end
	for _, s in slices do
		s.button.Size = if s.id == chosen then UDim2.fromOffset(214, 46) else UDim2.fromOffset(190, 40)
	end
end

local function openWheel()
	if ClientState.menuOpen or UiKit.current() ~= nil or not ClientState.inCrew() then
		return
	end
	wheel.Visible = true
	ClientState.wheelOpen = true -- LampFx frees the mouse while the wheel is up
	highlight(Vector2.zero)
end

-- The PING button (touch and mouse), bottom left above the thumbstick area.
local pingButton = UiKit.button(gui, "PING", UI.LILAC, "medium", 150, function()
	if wheel.Visible then
		close()
	else
		openWheel()
	end
end)
pingButton.AnchorPoint = Vector2.new(0, 1)
pingButton.Position = UDim2.new(0, 24, 1, -250)
local function showButton()
	pingButton.Visible = not ClientState.menuOpen
end
ClientState.MenuChanged:Connect(showButton)
showButton()

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then
		openWheel()
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1) and wheel.Visible then
		if chosen then
			send(chosen)
		else
			close()
		end
	end
end)
UserInputService.InputChanged:Connect(function(input: InputObject)
	if not wheel.Visible then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local centre = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local m = UserInputService:GetMouseLocation()
		highlight((m - centre) / 60)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 or input.KeyCode == Enum.KeyCode.Thumbstick1 then
		highlight(Vector2.new(input.Position.X, -input.Position.Y))
	end
end)

-- Markers (Fx ping) -------------------------------------------------------------------------------------

local mine: { [number]: { Instance } } = {}
ClientState.Fx.OnClientEvent:Connect(function(kind: string, data: any)
	if kind ~= "ping" or type(data) ~= "table" then
		return
	end
	local userId = tonumber(data.userId) or 0
	local id = tostring(data.id)
	local text = nil
	for _, p in LanternConfig.PINGS do
		if p.id == id then
			text = p.text
		end
	end
	if text == nil then
		return
	end
	local pos = ClientState.v3(ClientState.vec(data.pos))
	local who = Players:GetPlayerByUserId(userId)
	-- an invisible anchor part: a BillboardGui on a Terrain attachment did not draw in Studio
	local a = new("Part", {
		Name = "Ping",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Position = pos + Vector3.new(0, 1.5, 0),
		Parent = Workspace,
	})
	local board = new("BillboardGui", {
		Size = UDim2.fromOffset(230, 70),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 400,
		Parent = a,
	})
	local colour = COLOUR[id] or UI.GOLD
	new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colour,
		Parent = board,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 16) }), new("UIStroke", { Color = UI.CREAM, Thickness = 3 }) })
	for i, s in { text, if who then who.DisplayName else "" } do
		local label = new("TextLabel", {
			Position = UDim2.fromOffset(8, if i == 1 then 4 else 40),
			Size = UDim2.new(1, -16, 0, if i == 1 then 34 else 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			TextSize = if i == 1 then 24 else 18, -- billboard px: never under 12
			TextColor3 = UI.WHITE,
			Text = s,
			ZIndex = 2,
			Parent = board,
		})
		new("UIStroke", { Color = UI.INK, Thickness = 1.5, Parent = label })
	end
	local list = mine[userId] or {}
	table.insert(list, a)
	while #list > 3 do
		(table.remove(list, 1) :: Instance):Destroy()
	end
	mine[userId] = list
	task.delay(8, function()
		local i = table.find(list, a)
		if i then
			table.remove(list, i)
		end
		a:Destroy()
	end)
	ClientState.sound("tick", 0.3, pos, 1.3)
	ClientState.ping(userId, id)
end)
