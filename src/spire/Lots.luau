--!strict
-- The six lot shells (docs/architecture/spire.md 4.6): ground, approach, lobby collision walls with a
-- door gap, invisible floor slabs (one per floor above the lobby, the last being the roof), the lift
-- pad (SkyDeck prompt), the BUILD terminal (client-only prompt), the Hot Data part (Grab prompt) and
-- the sign. Every visual of the tower and plaza is built by the clients from the lot's `State`
-- attribute; nothing is ever read back from these parts. At most 15 parts per lot plus 1 per floor.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local TowerRules = require(Shared:WaitForChild("TowerRules"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Vec3 = TowerRules.Vec3

local Lots = {}

local COUNT = 6
Lots.COUNT = COUNT -- GDD A: 6 players, 6 lots; Max Players must match
local RING = 150 -- lot centre distance from the Grid Plaza centre
local HALF = TowerRules.TOWER.size / 2 -- 18
local TOWER_Z = TowerRules.TOWER.z -- 22
local FRONT_Z = TOWER_Z - HALF -- 4: lobby front wall, door gap x -4..4
local BACK_Z = TOWER_Z + HALF -- 40
local LOBBY_H = TowerRules.LOBBY_HEIGHT
local PROMPT_RANGE = 12
local GROUND = Color3.fromRGB(38, 40, 52)
local APPROACH = Color3.fromRGB(70, 74, 92)
local CYAN = Color3.fromRGB(0, 229, 255)
local HOT = Color3.fromRGB(255, 140, 40)
local SIGN = Color3.fromRGB(20, 22, 32)
local WHITE = Color3.new(1, 1, 1)

type View = {
	model: Model,
	frame: CFrame,
	slabs: { Part },
	hot: Part,
	grab: ProximityPrompt,
	title: TextLabel,
	info: TextLabel,
	ownerName: string,
	pending: SpireConfig.TowerState?, -- latest state not yet written (Lots.flush)
}

local views: { View } = {}
local promptEvent = Instance.new("BindableEvent")
Lots.prompts = promptEvent.Event -- (player: Player, lot: number, kind: "grab" | "skydeck")

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

-- Collision only: the clients draw the tower around it.
local function invisible(p: Part): Part
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function prompt(parent: Instance, name: string, action: string, range: number): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.Name = name
	pr.ActionText = action
	pr.HoldDuration = 0
	pr.MaxActivationDistance = range
	pr.RequiresLineOfSight = false
	pr.Parent = parent
	return pr
end

local function label(parent: Instance, size: number, position: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.94, size)
	l.Position = UDim2.fromScale(0.03, position)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.Text = ""
	l.Parent = parent
	return l
end

local function frameOf(n: number): CFrame
	local theta = math.rad((n - 1) * 60)
	return CFrame.lookAt(Vector3.new(RING * math.sin(theta), 0, -RING * math.cos(theta)), Vector3.zero)
end

local spire = Workspace:FindFirstChild("Spire")
if spire == nil then
	spire = Instance.new("Folder")
	spire.Name = "Spire"
	spire.Parent = Workspace
end
local lotsFolder = Instance.new("Folder")
lotsFolder.Name = "Lots"

for n = 1, COUNT do
	local frame = frameOf(n)
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	local model = Instance.new("Model")
	model.Name = `Lot{n}`
	model:SetAttribute("Owner", 0)
	model:SetAttribute("State", "")
	-- Ground top at y = 0; the pivot (PrimaryPart pivot) is the lot frame clients read.
	local ground = part(model, "Ground", Vector3.new(64, 1, 92), at(0, -0.5, 0), GROUND)
	ground.PivotOffset = CFrame.new(0, 0.5, 0)
	model.PrimaryPart = ground
	local approach = part(model, "Approach", Vector3.new(8, 0.1, 18), at(0, 0.05, -5), APPROACH)
	approach.CanCollide = false
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	invisible(part(lobby, "Back", Vector3.new(36, LOBBY_H, 1), at(0, LOBBY_H / 2, BACK_Z - 0.5), GROUND))
	invisible(part(lobby, "Left", Vector3.new(1, LOBBY_H, 36), at(-HALF + 0.5, LOBBY_H / 2, TOWER_Z), GROUND))
	invisible(part(lobby, "Right", Vector3.new(1, LOBBY_H, 36), at(HALF - 0.5, LOBBY_H / 2, TOWER_Z), GROUND))
	invisible(part(lobby, "FrontLeft", Vector3.new(14, LOBBY_H, 1), at(-11, LOBBY_H / 2, FRONT_Z + 0.5), GROUND))
	invisible(part(lobby, "FrontRight", Vector3.new(14, LOBBY_H, 1), at(11, LOBBY_H / 2, FRONT_Z + 0.5), GROUND))
	invisible(part(lobby, "Lintel", Vector3.new(8, LOBBY_H / 2, 1), at(0, LOBBY_H * 0.75, FRONT_Z + 0.5), GROUND))
	lobby.Parent = model
	local slabs = Instance.new("Folder")
	slabs.Name = "Slabs"
	slabs.Parent = model
	local centre = TowerRules.liftZone(1)
	local pad = part(
		model,
		"LiftPad",
		Vector3.new(0.2, 8, 8),
		at(centre.x, 0.1, centre.z) * CFrame.Angles(0, 0, math.pi / 2),
		CYAN
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.6
	pad.CanCollide = false
	prompt(pad, "SkyDeck", "Sky Deck", PROMPT_RANGE).Triggered:Connect(function(player: Player)
		promptEvent:Fire(player, n, "skydeck")
	end)
	local terminal = part(model, "Terminal", Vector3.new(3, 5, 1), at(12, 2.5, FRONT_Z + 3), APPROACH)
	prompt(terminal, "Build", "Build", 8) -- opens build mode on the client; the server ignores it
	local hot = part(model, "Hot", Vector3.new(2, 2, 2), at(0, 3, TOWER_Z), HOT)
	hot.Shape = Enum.PartType.Ball
	hot.Material = Enum.Material.Neon
	hot.CanCollide = false
	hot.CanQuery = false
	invisible(hot)
	local grab = prompt(hot, "Grab", "Grab", SpireConfig.HOT.range)
	grab.ObjectText = "Hot Data"
	grab.Enabled = false
	grab.Triggered:Connect(function(player: Player)
		promptEvent:Fire(player, n, "grab")
	end)
	-- Sign at the front-left corner, facing the Grid Plaza (local -Z is the Front face).
	part(model, "SignPost", Vector3.new(0.6, 3, 0.6), at(-28, 1.5, -44), SIGN)
	local sign = part(model, "Sign", Vector3.new(8, 4, 0.5), at(-28, 5, -44), SIGN)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local title = label(gui, 0.55, 0.05)
	local info = label(gui, 0.3, 0.65)
	title.Text = "FOR LEASE"
	model.Parent = lotsFolder
	views[n] = {
		model = model,
		frame = frame,
		slabs = {},
		hot = hot,
		grab = grab,
		title = title,
		info = info,
		ownerName = "",
		pending = nil,
	}
end
lotsFolder.Parent = spire

-- One invisible slab per floor surface above the lobby: Floor<n> for n = 2..floors + 1 (the roof).
local function syncSlabs(view: View, floors: number)
	for n = #view.slabs + 2, floors + 1 do
		local slab = invisible(
			part(
				view.model:FindFirstChild("Slabs") :: Folder,
				`Floor{n}`,
				Vector3.new(TowerRules.TOWER.size, 1, TowerRules.TOWER.size),
				view.frame * CFrame.new(0, TowerRules.floorY(n) - 0.5, TOWER_Z),
				GROUND
			)
		)
		table.insert(view.slabs, slab)
	end
	while #view.slabs > floors do
		(table.remove(view.slabs) :: Part):Destroy()
	end
end

function Lots.model(lot: number): Model
	return views[lot].model
end

function Lots.toLot(lot: number, pos: Vector3): Vec3
	local p = views[lot].frame:PointToObjectSpace(pos)
	return { x = p.X, y = p.Y, z = p.Z }
end

function Lots.toWorld(lot: number, v: Vec3): Vector3
	return views[lot].frame:PointToWorldSpace(Vector3.new(v.x, v.y, v.z))
end

-- The lot's owner, if one is in this server.
function Lots.owner(lot: number): Player?
	local id = views[lot] and views[lot].model:GetAttribute("Owner")
	return if type(id) == "number" and id ~= 0 then Players:GetPlayerByUserId(id) else nil
end

-- Lowest free lot; sets Owner.
function Lots.assign(player: Player): number?
	for n, view in views do
		if view.model:GetAttribute("Owner") == 0 then
			view.model:SetAttribute("Owner", player.UserId)
			view.ownerName = player.DisplayName
			return n
		end
	end
	return nil
end

-- Moves everyone but the owner who stands on the tower (above floorY(2) inside the footprint) to the
-- Grid Plaza with `text`, unless `keep(player)` says they may stay. `keep` may yield.
function Lots.evict(lot: number, text: string, keep: ((Player) -> boolean)?)
	local ownerId = views[lot].model:GetAttribute("Owner")
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character == nil or root == nil or player.UserId == ownerId then
			continue
		end
		local p = Lots.toLot(lot, root.Position)
		local onTower = p.y > TowerRules.floorY(2) and math.abs(p.x) <= HALF and p.z >= FRONT_Z and p.z <= BACK_Z
		if onTower and (keep == nil or not keep(player)) then
			character:PivotTo(CFrame.new(math.random(-12, 12), 3, math.random(-12, 12)))
			Remotes.notice(player, text)
		end
	end
end

-- Visitors off the tower, Owner = 0, State = "", slabs and Hot removed.
function Lots.free(lot: number)
	local view = views[lot]
	if view == nil then
		return
	end
	Lots.evict(lot, "That tower's owner left, so you are back on the Grid Plaza.")
	view.model:SetAttribute("Owner", 0)
	view.model:SetAttribute("State", "")
	view.pending = nil
	view.ownerName = ""
	syncSlabs(view, 0)
	Lots.setHot(lot, nil)
	view.title.Text = "FOR LEASE"
	view.info.Text = ""
end

-- Marks the lot dirty; Lots.flush writes the latest state.
function Lots.setState(lot: number, state: SpireConfig.TowerState)
	local view = views[lot]
	if view and view.model:GetAttribute("Owner") ~= 0 then
		view.pending = state
	end
end

-- 4 Hz: each dirty lot's State JSON once (latest wins), its slabs and its sign.
function Lots.flush()
	for _, view in views do
		local state = view.pending
		if state == nil then
			continue
		end
		view.pending = nil
		view.model:SetAttribute("State", HttpService:JSONEncode(state))
		syncSlabs(view, #state.floors)
		view.title.Text = SpireConfig.companyName(state.company)
		view.info.Text = `{view.ownerName} · {state.endorsements} endorsements`
	end
end

-- The Hot part at slotPos + (0, 3, 0) with Grab enabled, or hidden and disabled.
function Lots.setHot(lot: number, hot: State.Hot?)
	local view = views[lot]
	if hot then
		local s = TowerRules.slotPos(hot.floor, hot.slot)
		view.hot.CFrame = view.frame * CFrame.new(s.x, s.y + 3, s.z)
		view.hot.Transparency = 0
		view.grab.Enabled = true
	else
		view.hot.Transparency = 1
		view.grab.Enabled = false
	end
end

return Lots
