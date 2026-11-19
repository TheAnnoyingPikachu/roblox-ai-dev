--!strict
-- Animal portraits (decision 0044): a small picture frame showing a creature's model, from a still
-- copy the server publishes in ReplicatedStorage.Portraits (Creatures.publishPortraits). Client
-- only, display only. A frame shows a plain placeholder until its model has arrived.
--
-- Picture frames cost a little every frame they are visible, so a list of portraits inside a
-- scrolling frame calls Portrait.cull to hide the ones scrolled out of sight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StationAssets = require(Shared:WaitForChild("StationAssets"))
local UiLayout = require(Shared:WaitForChild("UiLayout"))

local Portrait = {}

local FOV = 26
local LOOK = Vector3.new(0.62, 0.22, -0.75).Unit -- from the front, a little to the right and above

-- rainbow: in its rainbow coat (decision 0058), whose texture the server leaves on the copy as "Coat"
export type Options = { size: UDim2?, background: Color3?, tint: Color3?, zoom: number?, rainbow: boolean? }

local function fill(view: ViewportFrame, source: Model, asset: string, options: Options)
	local entry = StationAssets[asset]
	if entry == nil or source.PrimaryPart == nil then
		return
	end
	local model = source:Clone()
	local coat = if options.rainbow then source:GetAttribute("Coat") else nil
	if type(coat) == "string" then
		for i, d in model:GetDescendants() do
			if d:IsA("MeshPart") and d.Material == Enum.Material.Neon then
				d.Color = Color3.fromHSV(i * 0.21 % 1, 0.8, 1)
			elseif d:IsA("MeshPart") then
				d.TextureID = coat
			end
		end
	end
	if options.tint then
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") and d.Material ~= Enum.Material.Neon then
				d.Color = options.tint
			end
		end
	end
	model.Parent = view
	local root = (model.PrimaryPart :: BasePart).CFrame -- faces the way the creature does (-Z)
	local middle = root * Vector3.new(0, entry.size[2] * 0.5, 0)
	local away = UiLayout.frameDistance(entry.size, FOV) * (options.zoom or 1)
	if string.match(asset, "^home_") or string.match(asset, "^area_") then -- a building: frame what is there
		local box, size = model:GetBoundingBox()
		root, middle = CFrame.new(box.Position), box.Position
		away = UiLayout.frameDistance({ size.X, size.Y, size.Z }, FOV) * 0.8 * (options.zoom or 1)
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(middle + root:VectorToWorldSpace(LOOK) * away, middle)
	camera.Parent = view
	view.CurrentCamera = camera
	for _, d in view:GetChildren() do
		if d:IsA("TextLabel") then
			d:Destroy()
		end
	end
end

-- A portrait of asset `asset` (an uploaded model name such as "creature_lion" or "foe_knight").
function Portrait.new(parent: Instance, asset: string, options: Options?): ViewportFrame
	local o = options or {}
	local view = Instance.new("ViewportFrame")
	view.Size = o.size or UDim2.fromOffset(88, 88)
	view.BackgroundColor3 = o.background or Color3.fromRGB(30, 27, 48)
	view.BorderSizePixel = 0
	view.Ambient = Color3.fromRGB(170, 170, 185)
	view.LightColor = Color3.fromRGB(255, 244, 228)
	view.LightDirection = Vector3.new(-0.6, -1, -0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = view
	local wait = Instance.new("TextLabel") -- until the model is there
	wait.Size, wait.BackgroundTransparency, wait.Text = UDim2.fromScale(1, 1), 1, "..."
	wait.TextColor3, wait.TextSize, wait.Font = Color3.fromRGB(150, 145, 180), 22, Enum.Font.FredokaOne
	wait.Parent = view
	view.Parent = parent

	local folder = ReplicatedStorage:FindFirstChild("Portraits")
	local source = folder and folder:FindFirstChild(asset)
	if source then
		fill(view, source :: Model, asset, o)
	else
		task.spawn(function()
			local f = ReplicatedStorage:WaitForChild("Portraits", 60)
			local m = f and f:WaitForChild(asset, 60)
			if m and view.Parent then
				fill(view, m :: Model, asset, o)
			end
		end)
	end
	return view
end

-- Show only the portraits inside `scroller` that are inside its window; hide the rest.
function Portrait.cull(scroller: ScrollingFrame)
	local top = scroller.AbsolutePosition.Y
	local bottom = top + scroller.AbsoluteSize.Y
	for _, d in scroller:GetDescendants() do
		if d:IsA("ViewportFrame") then
			local y = d.AbsolutePosition.Y
			d.Visible = y + d.AbsoluteSize.Y > top - 40 and y < bottom + 40
		end
	end
end

-- Keep `scroller`'s portraits culled as it scrolls, resizes and fills.
function Portrait.keepCulled(scroller: ScrollingFrame)
	local queued = false
	local function soon()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			Portrait.cull(scroller)
		end)
	end
	scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(soon)
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(soon)
	scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(soon)
	scroller.DescendantAdded:Connect(function(d)
		if d:IsA("ViewportFrame") then
			soon()
		end
	end)
end

return Portrait
