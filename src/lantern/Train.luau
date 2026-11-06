--!strict
-- The Lantern Express train (docs/architecture/lantern.md 4.3, decision 0018 section 2): four cars,
-- each an anchored base part with everything else welded to it, moved along the TrackRules path by
-- CFrame from the server's Heartbeat (anchored server cars, 0018's fallback; no character physics
-- runs on a moving car). Seats are server-assigned `Seat` parts with `Kind` and `Car` attributes,
-- turret heads (`lamp_turret_head`, `Seat` attribute) turn on a Weld's C0, and one invisible load
-- box per car serves the load test. Car models carry their asset names (`train_engine`, ...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local World = require(script.Parent:WaitForChild("World"))

local Train = {}

type Vec3 = LanternConfig.Vec3
type Car = {
	def: LanternConfig.Car,
	model: Model,
	base: BasePart,
	box: BasePart,
	body: { BasePart }, -- painted in the livery's first colour
	trim: { BasePart }, -- and its second
	fallback: { BasePart }, -- hidden when the car's mesh arrives
}

local BASE_Y = 1.8 -- the base part's centre above the rail top (floor top at 2.3)
local BASE_OFFSET = CFrame.new(0, BASE_Y, 0)
local PAL = World.PAL
local C3 = Color3.fromRGB

local cars: { Car } = {}
local seats: { Seat } = {}
local isSeat: { [Instance]: boolean } = {}
local heads: { [string]: { weld: Weld, at: CFrame, glass: BasePart } } = {} -- by turret seat id
local turrets: { { seat: Seat, car: Car, at: Vec3 } } = {}
local pending: { [Seat]: number } = {} -- seats just given out (Occupant can lag a frame)
local folder: Model
local frame = CFrame.new()

local function v(p: Vec3): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

-- A car-local part (car frame: origin at the rail top under the car's centre, -Z forward).
local function piece(car: Car, size: Vector3, at: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = Props.part(car.model, size, at, colour, material)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	table.insert(car.fallback, p)
	return p
end

local function cylinder(
	car: Car,
	length: number,
	diameter: number,
	at: CFrame,
	colour: Color3,
	vertical: boolean?
): Part
	local turn = if vertical then CFrame.Angles(0, 0, math.rad(90)) else CFrame.Angles(0, math.rad(90), 0)
	local p = piece(car, Vector3.new(length, diameter, diameter), at * turn, colour, Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function light(class: string, parent: Instance, range: number, brightness: number, colour: Color3): Light
	local l = Instance.new(class) :: Light
	l.Brightness = brightness
	l.Color = colour
	l.Shadows = class == "SpotLight"
	(l :: any).Range = range
	l.Parent = parent
	return l
end

local function wheels(car: Car, radius: number)
	local half = car.def.length / 2 - radius - 0.5
	for _, z in { -half, half } do
		for _, x in { -3.4, 3.4 } do
			local w = piece(
				car,
				Vector3.new(0.6, radius * 2, radius * 2),
				CFrame.new(x, radius, z),
				PAL.iron,
				Enum.Material.Metal
			)
			w.Shape = Enum.PartType.Cylinder
		end
	end
end

-- Part fallbacks shaped like the asset list (architecture 9).
local function decorate(car: Car)
	local id, len = car.def.id, car.def.length
	if id == "engine" then
		wheels(car, 2)
		table.insert(car.body, cylinder(car, 12, 5.2, CFrame.new(0, 5.3, -5), PAL.red))
		table.insert(car.trim, cylinder(car, 0.5, 5.6, CFrame.new(0, 5.3, -2), PAL.brass))
		cylinder(car, 1.5, 5.4, CFrame.new(0, 5.3, -10.6), PAL.iron)
		cylinder(car, 3.5, 1.8, CFrame.new(0, 9.4, -8.5), PAL.iron, true)
		table.insert(car.trim, cylinder(car, 0.6, 2.6, CFrame.new(0, 11.2, -8.5), PAL.brass, true))
		local lamp = piece(car, Vector3.new(1.8, 1.6, 1.4), CFrame.new(0, 8.6, -10.4), PAL.brass)
		local lens = piece(car, Vector3.new(1.4, 1.2, 0.2), CFrame.new(0, 8.6, -11.2), PAL.lamp, Enum.Material.Neon)
		local spot = light("SpotLight", lens, 60, 3, PAL.lamp) :: SpotLight
		spot.Angle = 50
		spot.Face = Enum.NormalId.Front
		lamp.Name = "Headlamp"
		for _, x in { -3.8, 3.8 } do
			table.insert(car.body, piece(car, Vector3.new(0.4, 6.5, 9), CFrame.new(x, 5.5, 6), PAL.red))
		end
		table.insert(car.trim, piece(car, Vector3.new(8.4, 0.5, 15.5), CFrame.new(0, 10.4, 3.2), PAL.roof))
		local fire = piece(car, Vector3.new(3, 2, 0.4), CFrame.new(0, 3.4, 1.3), PAL.ember, Enum.Material.Neon)
		light("PointLight", fire, 12, 1.5, PAL.ember)
		piece(car, Vector3.new(6, 1.6, 3), CFrame.new(0, 3.1, 9.2), C3(70, 62, 80), Enum.Material.Slate).Name = "Coal"
	elseif id == "cargo" then
		wheels(car, 1.3)
		for _, x in { -3.8, 3.8 } do
			table.insert(car.body, piece(car, Vector3.new(0.4, 2.6, len - 1), CFrame.new(x, 3.6, 0), PAL.red))
		end
		piece(car, Vector3.new(7, 1.8, len - 2), CFrame.new(0, 3.2, 0), C3(70, 62, 80), Enum.Material.Slate).Name =
			"Coal"
	elseif id == "lamp" then
		wheels(car, 1.3)
		table.insert(car.trim, piece(car, Vector3.new(8.2, 0.4, len), CFrame.new(0, 2.5, 0), PAL.brass))
		piece(car, Vector3.new(0.4, 4, 4), CFrame.new(3.8, 4.3, 0), PAL.timber).Name = "Rack"
	else
		wheels(car, 1.3)
		for _, x in { -3.8, 3.8 } do
			table.insert(car.body, piece(car, Vector3.new(0.4, 6, len), CFrame.new(x, 5.3, 0), PAL.red))
			for _, z in { -6, -2, 2, 6 } do
				piece(car, Vector3.new(0.2, 1.8, 2.4), CFrame.new(x * 1.03, 5.8, z), PAL.window, Enum.Material.Neon).Name =
					"Window"
			end
		end
		table.insert(car.trim, piece(car, Vector3.new(8.6, 0.6, len + 0.4), CFrame.new(0, 8.6, 0), PAL.roof))
		piece(car, Vector3.new(4, 0.8, 4), CFrame.new(0, 9.3, 0), PAL.iron).Name = "TurretDeck"
	end
end

local function buildCar(def: LanternConfig.Car): Car
	local model = Instance.new("Model")
	model.Name = def.model -- train_engine, train_car_cargo, ... (the asset names the client looks up)
	model:SetAttribute("Car", def.id)
	local car: Car =
		{ def = def, model = model, base = nil :: any, box = nil :: any, body = {}, trim = {}, fallback = {} }
	local base = Props.part(model, Vector3.new(8, 1, def.length), BASE_OFFSET, PAL.timber, Enum.Material.WoodPlanks)
	base.Name = "Base"
	model.PrimaryPart = base
	car.base = base
	decorate(car)
	for _, at in def.lanterns do
		local glass = piece(car, Vector3.new(0.8, 1.2, 0.8), CFrame.new(v(at)), PAL.lamp, Enum.Material.Neon)
		glass.Name = "Lantern"
		light("PointLight", glass, 8, 1, PAL.lamp)
	end
	local turretIndex = 0
	for _, s in def.seats do
		local seat = Instance.new("Seat")
		seat.Name = s.id
		seat.Size = Vector3.new(2, 1, 2)
		seat.CFrame = CFrame.new(v(s.at))
		seat.Color = PAL.timber
		seat.Material = Enum.Material.WoodPlanks
		seat.CanCollide = false
		seat.Anchored = true -- welded to the base below
		seat:SetAttribute("Kind", s.kind)
		seat:SetAttribute("Car", def.id)
		seat.Parent = model
		table.insert(seats, seat)
		isSeat[seat] = true
		if s.kind == "turret" then
			turretIndex += 1
			local at = def.turrets[turretIndex]
			table.insert(turrets, { seat = seat, car = car, at = at })
			if Models.night("lamp_turret_base", model, v(at) - Vector3.new(0, 2.2, 0)) == nil then
				local ring = cylinder(car, 1.6, 3, CFrame.new(v(at) - Vector3.new(0, 1.4, 0)), PAL.brass, true)
				ring.Name = "TurretBase"
			end
			local head =
				Props.part(model, Vector3.new(2.4, 2.4, 3.6), CFrame.new(v(at)), PAL.brass, Enum.Material.Metal)
			head.Name = "lamp_turret_head" -- the client finds the head nearest its seat by this name
			head:SetAttribute("Seat", s.id)
			head.CanCollide = false
			head.Massless = true
			local glass = Props.part(
				model,
				Vector3.new(2, 2, 0.2),
				CFrame.new(v(at) + Vector3.new(0, 0, -1.85)),
				PAL.lamp,
				Enum.Material.Neon
			)
			glass.CanCollide = false
			glass.Massless = true
			glass.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = head, glass
			w.Parent = glass
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1 = base, head
			local rest = BASE_OFFSET:Inverse() * CFrame.new(v(at))
			weld.C0 = rest
			weld.Parent = head
			head.Anchored = false
			heads[s.id] = { weld = weld, at = rest, glass = glass }
		end
	end
	local box = Props.part(
		model,
		Vector3.new(8 + 2 * LanternConfig.LOAD_BOX, 12, def.length + 2),
		CFrame.new(0, 6, 0),
		PAL.lamp
	)
	box.Name = "LoadBox"
	box.Transparency = 1
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Massless = true
	car.box = box
	-- Everything but the base and the turret heads (on their Weld) hangs on WeldConstraints.
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= base and p.Anchored then
			p.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = base, p
			w.Parent = p
		end
	end
	return car
end

function Train.build(parent: Instance)
	folder = Instance.new("Model")
	folder.Name = "Train"
	for _, def in LanternConfig.CARS do
		local car = buildCar(def)
		car.model.Parent = folder
		table.insert(cars, car)
	end
	folder.Parent = parent
	Train.drive("forest", 0)
	-- Meshes replace the fallback decor when they arrive (never: until LANTERN-011 has ids).
	for _, car in cars do
		task.spawn(function()
			local mesh = Models.night(car.def.model, car.model, car.base.Position - Vector3.new(0, BASE_Y, 0))
			if mesh then
				for _, p in car.fallback do
					p.Transparency = 1
				end
				car.base.Transparency = 1
				Models.ghost(mesh)
				local _, size = mesh:GetBoundingBox()
				Models.attach(mesh, car.base, CFrame.new(0, size.Y / 2 - BASE_Y, 0))
			end
		end)
	end
	-- The lamp heads' mesh (glass front on -Z, symmetric about its centre) replaces the block and glass.
	for _, h in heads do
		task.spawn(function()
			local head = h.weld.Part1 :: BasePart
			local mesh = Models.night("lamp_turret_head", head, head.Position)
			if mesh then
				Models.ghost(mesh)
				Models.attach(mesh, head, CFrame.new())
				head.Transparency = 1
				h.glass.Transparency = 1
			end
		end)
	end
end

-- Places every car along `track` with the engine's front at distance d.
function Train.drive(track: string, d: number)
	for _, car in cars do
		local pos, fwd = World.at(track, d - car.def.offset - car.def.length / 2)
		car.base.CFrame = CFrame.lookAt(pos, pos + fwd) * BASE_OFFSET
	end
	local pos, fwd = World.at(track, d)
	local origin = Vector3.new(pos.X, 0, pos.Z)
	frame = CFrame.lookAt(origin, origin + fwd)
end

-- The train frame (architecture 2): TrackRules.at(track, d) as a CFrame, y 0, -Z forward. The client
-- rebuilds the same frame from the replicated D, so beams, wisps and lanterns agree on both sides.
function Train.frame(): CFrame
	return frame
end

local function toTrain(world: Vector3): Vec3
	local p = Train.frame():PointToObjectSpace(world)
	return { x = p.X, y = p.Y, z = p.Z }
end

local function carFrame(car: Car): CFrame
	return car.base.CFrame * BASE_OFFSET:Inverse()
end

-- Lantern points in the train frame, from the car poses.
function Train.lanternPoints(): { Vec3 }
	local out = {}
	for _, car in cars do
		local cf = carFrame(car)
		for _, at in car.def.lanterns do
			table.insert(out, toTrain(cf * v(at)))
		end
	end
	return out
end

-- Every turret seat with its lamp origin in the train frame.
function Train.turrets(): { { seat: Seat, origin: Vec3 } }
	local out = {}
	for _, t in turrets do
		table.insert(out, { seat = t.seat, origin = toTrain(carFrame(t.car) * v(t.at)) })
	end
	return out
end

-- Turns a turret head to `dir` (train frame; on the gentle night curves the car frame is within a
-- degree of it).
function Train.aimHead(seatId: string, dir: Vec3)
	local head = heads[seatId]
	if head then
		head.weld.C0 = head.at * CFrame.lookAt(Vector3.zero, v(dir)).Rotation
	end
end

function Train.isSeat(part: Instance?): boolean
	return part ~= nil and isSeat[part] == true
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then humanoid else nil
end

function Train.seatOf(player: Player): Seat?
	local humanoid = humanoidOf(player)
	local part = humanoid and humanoid.SeatPart
	-- SeatPart can stay set after the server removes the weld; Occupant is the truth.
	return if part and isSeat[part] and (part :: Seat).Occupant == humanoid then part :: Seat else nil
end

-- UserId -> seat kind of every player sitting on the train (the server's Seat.Occupant).
function Train.seats(): { [number]: LanternConfig.SeatKind? }
	local out = {}
	for _, seat in seats do
		local occupant = seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if player then
			out[player.UserId] = seat:GetAttribute("Kind") :: any
		end
	end
	return out
end

local function free(kind: string?): Seat?
	local t = os.clock()
	for _, seat in seats do
		if
			seat.Occupant == nil
			and (kind == nil or seat:GetAttribute("Kind") == kind)
			and t - (pending[seat] or -1) > 1
		then
			return seat
		end
	end
	return nil
end

local function unweld(seat: Seat)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
end

-- Seats `player` in a free seat of `kind` (any kind when nil, or when none is free unless
-- `strict`). Returns the kind sat in, or nil. A player already in a seat of that kind stays.
function Train.seat(player: Player, kind: string?, strict: boolean?): string?
	local humanoid = humanoidOf(player)
	if humanoid == nil then
		return nil
	end
	local current = Train.seatOf(player)
	if current and (kind == nil or current:GetAttribute("Kind") == kind) then
		return current:GetAttribute("Kind") :: string
	end
	local seat = (kind and free(kind)) or (if current or (kind and strict) then nil else free(nil))
	if seat == nil then
		return if current then current:GetAttribute("Kind") :: string else nil
	end
	if current then
		unweld(current)
	end
	local character = player.Character :: Model
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = false
	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 2.5, 0))
	pending[seat] = os.clock()
	seat:Sit(humanoid)
	return seat:GetAttribute("Kind") :: string
end

-- A standing spot beside the train on `side` (+1 right of the track), level with the car at
-- `along` studs behind the engine's front.
function Train.door(side: number, along: number?): CFrame
	local at = frame * Vector3.new(side * (World.PLATFORM_NEAR + 3), World.PLATFORM_Y + 3, along or 39)
	return CFrame.lookAt(at, at + frame.RightVector * side)
end

-- Removes the seat weld and moves the character to `cf`. The owning client still simulates the
-- seated pose until the weld removal reaches it and overwrote a plain move in Studio, so the server
-- owns the character's physics for the move and hands it back 0.4 s later.
local function stepOff(seat: Seat, character: Model, cf: CFrame)
	unweld(seat)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid then
		humanoid.Sit = false
	end
	local owned = root ~= nil and pcall(root.SetNetworkOwner, root, nil)
	character:PivotTo(cf)
	local player = Players:GetPlayerFromCharacter(character)
	task.delay(0.4, function()
		local sat = humanoid and humanoid.SeatPart -- may still name the old seat: check its Occupant
		if character.Parent and not (sat and sat:IsA("Seat") and sat.Occupant == humanoid) then
			character:PivotTo(cf)
		end
		if owned and root and root.Parent and not root.Anchored and player then
			pcall(root.SetNetworkOwner, root, player)
		end
	end)
end

-- Stands `player` up and puts them beside their seat on `side` (or at `at`).
function Train.stand(player: Player, side: number, at: CFrame?)
	local seat = Train.seatOf(player)
	if seat and player.Character then
		local along = Train.frame():PointToObjectSpace(seat.Position).Z
		stepOff(seat, player.Character, at or Train.door(side, along))
	end
end

-- Stands up whoever sits in `seat` and steps them off to the side (the menu-player rule).
function Train.clearSeat(seat: Seat, side: number)
	local occupant = seat.Occupant
	local character = occupant and occupant.Parent
	if character and character:IsA("Model") then
		local along = Train.frame():PointToObjectSpace(seat.Position).Z
		stepOff(seat, character, Train.door(side, along) * CFrame.new(0, 0, -3))
	else
		unweld(seat)
	end
end

-- Calls `fn(seat)` whenever a seat's occupant changes.
function Train.onOccupant(fn: (seat: Seat) -> ())
	for _, seat in seats do
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			fn(seat)
		end)
	end
end

function Train.inLoadBox(pos: Vector3): boolean
	for _, car in cars do
		local p = car.box.CFrame:PointToObjectSpace(pos)
		local half = car.box.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- Studs from `pos` to the nearest car (horizontal), for the `sit` reach check.
function Train.distance(pos: Vector3): number
	local best = math.huge
	for _, car in cars do
		local p = car.base.CFrame:PointToObjectSpace(pos)
		local dx = math.max(0, math.abs(p.X) - 4)
		local dz = math.max(0, math.abs(p.Z) - car.def.length / 2)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

-- The conductor's livery (cosmetic colours: body, trim).
function Train.paint(colours: { { number } })
	local body = colours[1] and Color3.fromRGB(colours[1][1], colours[1][2], colours[1][3])
	local trim = colours[2] and Color3.fromRGB(colours[2][1], colours[2][2], colours[2][3])
	for _, car in cars do
		for _, p in car.body do
			p.Color = body or PAL.red
		end
		for _, p in car.trim do
			p.Color = trim or PAL.roof
		end
	end
end

return Train
