--!strict
-- Greybox city collision (docs/architecture/spire.md 4.1, 4.6): the round Grid Plaza between the
-- six lots, the street slab around them, invisible edge walls, and the Top Spires and Market boards
-- (SurfaceGui). No decoration: skyline, traffic, rain and lights are client-side (SPIRE-007).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireEconomy = require(Shared:WaitForChild("SpireEconomy"))
local Models = require(script.Parent:WaitForChild("Models"))

local City = {}

local PLAZA_RADIUS = 104 -- the lots' front edges (ring 150 - 46)
local WORLD = 520 -- street slab side; the lots reach 196 + 32 from the centre
local WALL_HEIGHT = 60
local PLAZA = Color3.fromRGB(28, 30, 42)
local STREET = Color3.fromRGB(22, 23, 30)
local BOARD = Color3.fromRGB(16, 18, 28)
local CYAN = Color3.fromRGB(0, 229, 255)
local WHITE = Color3.new(1, 1, 1)

local boardRows: TextLabel? = nil
local marketRows: { TextLabel } = {}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, colour: Color3, height: number, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, height)
	l.LayoutOrder = order
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = colour
	l.Text = text
	l.Parent = parent
	return l
end

-- A board on a post at `at` (ground), its front facing the plaza centre; returns its SurfaceGui.
local function board(parent: Instance, name: string, at: Vector3): SurfaceGui
	local post = part(parent, `{name}Post`, Vector3.new(1, 4, 1), CFrame.new(at + Vector3.new(0, 2, 0)), BOARD)
	local centre = at + Vector3.new(0, 9, 0)
	local b = part(parent, name, Vector3.new(16, 10, 0.6), CFrame.lookAt(centre, Vector3.new(0, centre.Y, 0)), BOARD)
	-- Blender frame around the board once uploaded (SpireAssets board_frame); the client then skips
	-- its own neon frame. The board part keeps the SurfaceGui.
	local _, yaw = b.CFrame:ToOrientation()
	local frame = Models.spire("board_frame", parent, at, math.deg(yaw))
	if frame then
		Models.ghost(frame)
		post.Transparency = 1
		b:SetAttribute("Framed", true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = b
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	return gui
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function eventName(id: any): string
	for _, e in SpireConfig.EVENTS do
		if e.id == id then
			return e.name
		end
	end
	return "Normal"
end

-- Top Spires rows (Profiles.topEarned).
function City.board(rows: { { name: string, earned: number } })
	if boardRows == nil then
		return
	end
	local lines = {}
	for i, row in rows do
		table.insert(lines, `{i}. {row.name}  ¢{SpireEconomy.short(row.earned)}`)
	end
	if #lines == 0 then
		table.insert(lines, "Build your tower to join the board!")
	end
	boardRows.Text = table.concat(lines, "\n")
end

-- Market board from the SpireStatus table.
function City.market(status: { [string]: any })
	if marketRows[1] == nil then
		return
	end
	local event = status.event
	local left = clock(tonumber(status.eventLeft) or 0)
	local forecast = if type(status.forecast) == "table" then status.forecast else {}
	marketRows[1].Text = if event == "normal"
		then `Normal market · next window in {left}`
		else `{eventName(event)} · {left} left`
	marketRows[2].Text = `Next: {eventName(forecast[1])}`
	marketRows[3].Text = `Then: {eventName(forecast[2])}`
end

function City.build(): {
	board: (rows: { { name: string, earned: number } }) -> (),
	market: (status: { [string]: any }) -> (),
}
	local spire = Workspace:FindFirstChild("Spire")
	if spire == nil then
		spire = Instance.new("Folder")
		spire.Name = "Spire"
		spire.Parent = Workspace
	end
	local folder = Instance.new("Folder")
	folder.Name = "City"
	-- Plaza disc top at y = 0, level with the lots; the street sits 0.1 lower so nothing z-fights.
	local plaza = part(
		folder,
		"GridPlaza",
		Vector3.new(1, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2),
		CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		PLAZA
	)
	plaza.Shape = Enum.PartType.Cylinder
	part(folder, "Street", Vector3.new(WORLD, 1, WORLD), CFrame.new(0, -0.6, 0), STREET)
	for k = 0, 3 do
		local wall = part(
			folder,
			`Edge{k + 1}`,
			Vector3.new(WORLD, WALL_HEIGHT, 2),
			CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, WALL_HEIGHT / 2, WORLD / 2 + 1),
			STREET
		)
		wall.Transparency = 1
		wall.CastShadow = false
	end
	local top = board(folder, "TopSpires", Vector3.new(-30, 0, 0))
	label(top, "TOP SPIRES", CYAN, 0.16, 0)
	local rows = label(top, "", WHITE, 0.82, 1)
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	boardRows = rows
	local market = board(folder, "MarketBoard", Vector3.new(30, 0, 0))
	label(market, "MARKET PULSE", CYAN, 0.25, 0)
	for k = 1, 3 do
		marketRows[k] = label(market, "", WHITE, 0.25, k)
	end
	folder.Parent = spire
	City.board({})
	return { board = City.board, market = City.market }
end

return City
