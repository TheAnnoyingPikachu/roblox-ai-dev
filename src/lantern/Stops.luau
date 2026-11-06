--!strict
-- Lantern Express stops (docs/architecture/lantern.md 4.4): the tile from the seeded kit (part
-- fallbacks from `Tile.blocks` until a `stop_<tile>` model id exists), its collision boxes, one ground
-- collider, invisible edges, and every item with its server ProximityPrompts. Built on `approach`,
-- about 10 s before the train halts; `sync` follows the run's item states after every change.
-- Stop frame (World.site, the art's LAYOUT frame): Site * Vector3.new(x, y, depth), x across the
-- tile, y up from the plate, depth from the platform deck's track edge (deck 0 to 10, ramp to 15).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local LootRules = require(Shared:WaitForChild("LootRules"))
local Carry = require(script.Parent:WaitForChild("Carry"))
local Models = require(script.Parent:WaitForChild("Models"))
local Props = require(script.Parent:WaitForChild("Props"))
local World = require(script.Parent:WaitForChild("World"))

local Stops = {}

local C3 = Color3.fromRGB
local PAL = World.PAL
local STOP = LanternConfig.STOP

Stops.NAMES = {
	coal = "Coal sack",
	parts = "Parts bag",
	oil = "Oil can",
	supply = "Supply crate",
	critter = "Critter crate",
} :: { [string]: string }
local MODELS = {
	coal = "item_coal_sack",
	parts = "item_parts_bag",
	oil = "item_oil_can",
	supply = "item_supply_crate",
	critter = "item_critter_crate",
}
local LOOK = {
	coal = { size = Vector3.new(1.6, 1.4, 1.2), colour = C3(70, 62, 80), material = Enum.Material.Fabric },
	parts = { size = Vector3.new(1.6, 1.2, 1.2), colour = C3(128, 84, 60), material = Enum.Material.Fabric },
	oil = { size = Vector3.new(1, 1.6, 1), colour = C3(240, 190, 60), material = Enum.Material.Metal },
	supply = { size = Vector3.new(3, 3, 3), colour = C3(150, 105, 70), material = Enum.Material.WoodPlanks },
	critter = { size = Vector3.new(3.6, 3, 2.6), colour = C3(170, 120, 80), material = Enum.Material.WoodPlanks },
}

type Entry = {
	model: Model,
	body: BasePart,
	pick: ProximityPrompt,
	help: ProximityPrompt,
	kind: string,
	state: string,
	x: number,
	z: number,
	by: BasePart?,
	helper: BasePart?,
	slot: number,
}

local folder: Model? = nil
local site: CFrame? = nil
local entries: { [number]: Entry } = {}

local function v(p: LanternConfig.Vec3): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function prompt(body: BasePart, name: string, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.3
	p.MaxActivationDistance = LanternConfig.REACH
	p.RequiresLineOfSight = false
	p.Parent = body
	return p
end

local function itemModel(parent: Instance, item: LootRules.Item, onPrompt: (Player, number, string) -> ()): Entry
	local look = LOOK[item.kind]
	local model = Instance.new("Model")
	model.Name = `Item{item.id}`
	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("Kind", item.kind)
	model:SetAttribute("Big", item.big)
	if item.rarity then
		model:SetAttribute("Rarity", item.rarity) -- the glow shows the rarity; the species stays hidden
	end
	local body = Props.part(model, look.size, CFrame.new(), look.colour, look.material)
	body.Name = "Body"
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	model.PrimaryPart = body
	local extras: { BasePart } = {}
	if item.kind == "critter" then
		local rgb = (LanternConfig.RARITY_COLOURS :: any)[item.rarity or "common"]
		local colour = C3(rgb[1], rgb[2], rgb[3])
		for _, x in { -2.05, 2.05 } do
			table.insert(extras, Props.part(model, Vector3.new(0.5, 0.4, 1.4), CFrame.new(x, 0.6, 0), PAL.timber))
		end
		table.insert(
			extras,
			Props.part(model, Vector3.new(2.4, 0.8, 0.1), CFrame.new(0, 0.3, -1.33), colour, Enum.Material.Neon)
		)
		local glow = Instance.new("PointLight")
		glow.Color = colour
		glow.Range = 8
		glow.Brightness = 1.5
		glow.Shadows = false
		glow.Parent = body
	elseif item.kind == "oil" then
		table.insert(extras, Props.part(model, Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 0.95, 0), PAL.brass))
	end
	if Models.nightReady(MODELS[item.kind]) then -- preloaded at start; never yield inside the tick
		local mesh = Models.night(MODELS[item.kind], model, Vector3.new(0, -look.size.Y / 2, 0))
		if mesh then
			Models.ghost(mesh)
			Models.attach(mesh, body, CFrame.new())
			body.Transparency = 1
			for _, p in extras do
				p:Destroy()
			end
			extras = {}
		end
	end
	for _, p in extras do
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = body, p
		weld.Parent = p
	end
	local name = Stops.NAMES[item.kind]
	local pick = prompt(body, "Pick", "Pick up", name)
	local help = prompt(body, "Help", "Help carry", name)
	help.Enabled = false
	pick.Triggered:Connect(function(player)
		onPrompt(player, item.id, "pick")
	end)
	help.Triggered:Connect(function(player)
		onPrompt(player, item.id, "help")
	end)
	model.Parent = parent
	return {
		model = model,
		body = body,
		pick = pick,
		help = help,
		kind = item.kind,
		state = "",
		x = 0,
		z = 0,
		by = nil,
		helper = nil,
		slot = 0,
	}
end

-- How a fallback block looks, by the art's block name (tiles.py LAYOUT).
local function kindOf(name: string): string
	if string.match(name, "^tree") or string.match(name, "^apple") then
		return "tree"
	elseif name == "stream" or name == "pool" or name == "pond" or name == "water" or name == "sea" then
		return "water"
	elseif string.match(name, "^fence") or string.match(name, "^rock") then
		return "low"
	elseif
		({ hay_1 = 1, hay_2 = 1, hay_3 = 1, cart = 1, crates = 1, crates_2 = 1, hives = 1, boat = 1, nets = 1 })[name]
	then
		return "low"
	elseif string.match(name, "^table") or name == "sign" or name == "well" or name == "coop" then
		return "low"
	end
	return "house"
end

-- The tile's part fallback (architecture 9): the art's blocks as colliders, dressed by kind (houses
-- get a plum roof, a brick plinth and two lit windows towards the track), the platform deck and its
-- ramp, and the street lamps with their PointLights. Returns the dressing hidden under the mesh.
local function dress(model: Model, tile: LanternConfig.Tile, at: CFrame): { BasePart }
	local dressing = {}
	local function add(size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?, collide: boolean?): Part
		local p = Props.part(model, size, cf, colour, material)
		p.CanCollide = collide == true
		table.insert(dressing, p)
		return p
	end
	for _, b in tile.blocks do
		local cf = at * CFrame.new(b.at.x, b.at.y, b.at.z)
		local kind = kindOf(b.name or "")
		local colour = if kind == "house" then PAL.cream elseif kind == "water" then C3(70, 110, 150) else PAL.timber
		local block = add(v(b.size), cf, colour, if kind == "water" then Enum.Material.Glass else nil, true)
		block.Name = "Block"
		if kind == "water" then
			block.Transparency = 0.3
		elseif kind == "tree" then
			block.Color = PAL.bark
			local crown = add(Vector3.new(9, 9, 9), cf * CFrame.new(0, b.size.y / 2, 0), PAL.pine)
			crown.Shape = Enum.PartType.Ball
		elseif kind == "house" then
			add(Vector3.new(b.size.x + 2, 3, b.size.z + 2), cf * CFrame.new(0, b.size.y / 2 + 1.5, 0), PAL.roof)
			local plinth =
				add(Vector3.new(b.size.x + 0.4, 2, b.size.z + 0.4), cf * CFrame.new(0, 1 - b.size.y / 2, 0), PAL.brick)
			plinth.Material = Enum.Material.Brick
			for _, x in { -b.size.x / 4, b.size.x / 4 } do -- the face towards the track is -Z
				add(
					Vector3.new(2.4, 2.4, 0.2),
					cf * CFrame.new(x, b.size.y * 0.1, -b.size.z / 2 - 0.1),
					PAL.window,
					Enum.Material.Neon
				)
			end
			if b.size.y >= 40 then -- the windmill and the lighthouse
				add(Vector3.new(4, 4, 4), cf * CFrame.new(0, b.size.y / 2 + 5, 0), PAL.lamp, Enum.Material.Neon).Shape =
					Enum.PartType.Ball
			end
		end
	end
	-- The deck (depth 0 to 10, 1.8 high) and its ramp down to the plate at 15 collide even under the mesh.
	local deck = LanternConfig.TILE_DECK
	local floor = Props.part(
		model,
		Vector3.new(deck.length, deck.height, deck.depth),
		at * CFrame.new(0, deck.height / 2, deck.depth / 2),
		PAL.brick,
		Enum.Material.Brick
	)
	floor.Name = "Deck"
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(deck.length, deck.height, deck.ramp - deck.depth)
	-- A wedge rises towards its back (+Z); turned half round it rises towards the deck.
	ramp.CFrame = at * CFrame.new(0, deck.height / 2, (deck.depth + deck.ramp) / 2) * CFrame.Angles(0, math.pi, 0)
	ramp.Color = PAL.brick
	ramp.Material = Enum.Material.Brick
	ramp.Parent = model
	table.insert(
		dressing,
		add(Vector3.new(deck.length, 0.1, 0.8), at * CFrame.new(0, deck.height + 0.05, 0.6), PAL.cream)
	)
	for _, l in tile.lamps do
		local base = at * CFrame.new(l.x, 0, l.z)
		add(Vector3.new(0.5, 7, 0.5), base * CFrame.new(0, 3.5, 0), PAL.iron, Enum.Material.Metal)
		local head = add(Vector3.new(1.2, 1.4, 1.2), base * CFrame.new(0, 7.5, 0), PAL.lamp, Enum.Material.Neon)
		head.Name = "StreetLamp"
		local light = Instance.new("PointLight") -- art bible 3: the code's light at 7.5 up, range 18
		light.Range = 18
		light.Brightness = 1.2
		light.Color = PAL.lamp
		light.Shadows = false
		light.Parent = head
	end
	return dressing
end

-- The tile mesh's plate is flat and dark (Studio integration): grass terrain edge to edge from the
-- ramp's foot to the back edge, a ground lane down the middle, water blocks left open. Terrain renders
-- its surface 2 studs above a filled block's top (4-stud voxels centred on multiples of 4), so the
-- blocks below end 2 under the wanted surface. It stays after the stop: a grass patch by the track.
local GRASS_TOP = 0.15 -- above the plate (no z-fighting); items still stand clear of the blades
local function grass(tile: LanternConfig.Tile, at: CFrame)
	local terrain = workspace.Terrain
	local ramp = LanternConfig.TILE_DECK.ramp
	local depth = STOP.depth - ramp
	local function fill(x: number, z: number, size: Vector3, material: Enum.Material)
		terrain:FillBlock(at * CFrame.new(x, GRASS_TOP - 2 - size.Y / 2, z), size, material)
	end
	fill(0, ramp + depth / 2, Vector3.new(STOP.width, 4, depth), Enum.Material.Grass)
	fill(0, ramp + depth / 2, Vector3.new(10, 4, depth), Enum.Material.Ground)
	for _, b in tile.blocks do
		if kindOf(b.name or "") == "water" then
			terrain:FillBlock(
				at * CFrame.new(b.at.x, b.at.y, b.at.z),
				v(b.size) + Vector3.new(2, 12, 2),
				Enum.Material.Air
			)
		end
	end
end

-- Seeded decor along the side and back borders, at least 9 studs from every site, block and lamp and
-- clear of the lane; ghosted, so it never blocks a site or the way back.
local DECOR = { "decor_pine", "decor_pine", "decor_birch", "decor_birch", "decor_rock" }
local function scatter(model: Model, tile: LanternConfig.Tile, at: CFrame, seed: number)
	local rng = Random.new(seed)
	local spots = {}
	for z = 24, 144, 12 do
		table.insert(spots, Vector3.new(-55, 0, z))
		table.insert(spots, Vector3.new(55, 0, z))
	end
	for x = -48, 48, 12 do
		table.insert(spots, Vector3.new(x, 0, 154))
	end
	local function clear(p: Vector3): boolean
		if math.abs(p.X) < 12 then
			return false -- the lane
		end
		for _, list in { tile.small, tile.big, tile.lamps } do
			for _, s in list do
				if (Vector3.new(s.x, 0, s.z) - p).Magnitude < 9 then
					return false
				end
			end
		end
		for _, b in tile.blocks do
			if math.abs(b.at.x - p.X) < b.size.x / 2 + 6 and math.abs(b.at.z - p.Z) < b.size.z / 2 + 6 then
				return false
			end
		end
		return true
	end
	for _, spot in spots do
		local p = spot + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		if rng:NextNumber() < 0.7 and clear(p) then
			local name = DECOR[rng:NextInteger(1, #DECOR)]
			local scale = rng:NextNumber(0.8, 1.1)
			local decor = Models.night(name, model, (at * CFrame.new(p)).Position, rng:NextNumber(0, 360), scale)
			if decor then
				Models.ghost(decor)
			end
		end
	end
end

-- Builds the stop for `stop` (LootRules) at the site `at` (World.site). `onPrompt(player, itemId,
-- "pick" | "help")` handles the prompts.
function Stops.build(stop: LootRules.Stop, at: CFrame, parent: Instance, onPrompt: (Player, number, string) -> ())
	Stops.clear()
	site = at
	local model = Instance.new("Model")
	model.Name = "Stop"
	model:SetAttribute("Tile", stop.tile)
	model:SetAttribute("Line", stop.line)
	model:SetAttribute("Leg", stop.leg)
	model:SetAttribute("Index", stop.index)
	model:SetAttribute("Site", at) -- the stop frame: Site * Vector3.new(x, y, depth)
	local plate = World.TILE_Y - World.GROUND_Y -- the ground collider reaches down to the terrain
	local ground = Props.part(
		model,
		Vector3.new(STOP.width, plate, STOP.depth),
		at * CFrame.new(0, -plate / 2, STOP.depth / 2),
		PAL.grass,
		Enum.Material.Grass
	)
	ground.Name = "Ground"
	local lane = Props.part(
		model,
		Vector3.new(14, 0.1, STOP.depth - 15),
		at * CFrame.new(0, 0.05, (STOP.depth + 15) / 2),
		PAL.path,
		Enum.Material.Ground
	)
	lane.CanCollide = false
	for _, edge in
		{
			{ -STOP.width / 2 - 0.5, STOP.depth / 2, 1, STOP.depth },
			{ STOP.width / 2 + 0.5, STOP.depth / 2, 1, STOP.depth },
			{ 0, STOP.depth + 0.5, STOP.width + 2, 1 },
		}
	do
		local wall =
			Props.part(model, Vector3.new(edge[3], 30, edge[4]), at * CFrame.new(edge[1], 15, edge[2]), PAL.fog)
		wall.Name = "Edge"
		wall.Transparency = 1
	end
	local tile = LanternConfig.tile(stop.tile) :: LanternConfig.Tile
	local dressing = dress(model, tile, at)
	grass(tile, at)
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = model
	for id, item in stop.items do
		entries[id] = itemModel(items, item, onPrompt)
	end
	folder = model
	model.Parent = parent
	Stops.sync(stop, {}, function()
		return nil
	end)
	-- The FBX arrives turned half round (tiles.py): at yaw 0 its x is the stop frame's x and its
	-- depth runs along +Z, so the mesh takes the site's own heading. A mirrored tile at integration
	-- is fixed here (the yaw), never in the art.
	local look = at.LookVector
	task.spawn(function()
		local base = (at * CFrame.new(0, World.RAIL_Y - World.TILE_Y, STOP.depth / 2)).Position -- the plate's base
		local mesh = Models.night(`stop_{stop.tile}`, model, base, math.deg(math.atan2(-look.X, -look.Z)))
		if mesh and folder == model then
			Models.ghost(mesh)
			for _, p in dressing do
				p.Transparency = 1
			end
			for _, p in model:GetChildren() do
				if
					p:IsA("BasePart")
					and (p.Name == "Block" or p.Name == "Deck" or p.Name == "Ramp" or p.Name == "Ground")
				then
					p.Transparency = 1
				end
			end
		elseif mesh then
			mesh:Destroy()
		end
		if folder == model then
			scatter(model, tile, at, string.byte(stop.tile) * 100 + stop.leg * 10 + stop.index)
		end
	end)
end

-- Makes every item model match its state: free items lie at their stop position with "Pick up",
-- carried ones hang on their carrier (a lone critter crate offers "Help carry"), loaded and lost
-- ones go. `rootOf(userId)` gives a carrier's HumanoidRootPart.
function Stops.sync(stop: LootRules.Stop?, carries: CarryRules.Carries, rootOf: (number) -> BasePart?)
	if stop == nil or site == nil then
		return
	end
	for id, e in entries do
		local item = stop.items[id]
		if item == nil or item.state == "loaded" or item.state == "lost" then
			Carry.release(e.body)
			e.model:Destroy()
			entries[id] = nil
		elseif item.state == "free" then
			if e.state ~= "free" or e.x ~= item.pos.x or e.z ~= item.pos.z then
				Carry.release(e.body)
				e.body.CFrame = (site :: CFrame) * CFrame.new(item.pos.x, item.pos.y + e.body.Size.Y / 2, item.pos.z)
				e.pick.Enabled, e.help.Enabled = true, false
				e.state, e.x, e.z, e.by, e.helper = "free", item.pos.x, item.pos.z, nil, nil
			end
		else
			local c = carries[item.by :: number]
			local slot = (c and table.find(c.small, id)) or 1
			local by = rootOf(item.by :: number)
			local helper = if item.helper then rootOf(item.helper) else nil
			if by and (e.state ~= "carried" or e.by ~= by or e.helper ~= helper or e.slot ~= slot) then
				Carry.hold(e.body, e.kind, slot, by, helper)
				e.pick.Enabled = false
				e.help.Enabled = e.kind == "critter" and item.helper == nil
				e.state, e.by, e.helper, e.slot = "carried", by, helper, slot
			end
		end
	end
end

function Stops.clear()
	for _, e in entries do
		Carry.release(e.body)
	end
	entries = {}
	if folder then
		folder:Destroy()
	end
	folder, site = nil, nil
end

function Stops.site(): CFrame?
	return site
end

-- Stop frame depth of a world position for the fog test: nil without a stop and on the deck (GDD C2:
-- the crew on the platform is seated when the fog reaches it, never caught).
function Stops.depth(pos: Vector3): number?
	local depth = if site then site:PointToObjectSpace(pos).Z else nil
	return if depth and depth > LanternConfig.TILE_DECK.depth then depth else nil
end

-- A world position in the stop frame, on the tile, at the height of the deck, ramp or plate there
-- (for drops).
function Stops.toStop(pos: Vector3): LanternConfig.Vec3?
	if site == nil then
		return nil
	end
	local p = site:PointToObjectSpace(pos)
	local deck = LanternConfig.TILE_DECK
	local half = STOP.width / 2 - 2
	local z = math.clamp(p.Z, 1, STOP.depth - 2)
	local y = deck.height * math.clamp((deck.ramp - z) / (deck.ramp - deck.depth), 0, 1)
	return { x = math.clamp(p.X, -half, half), y = y, z = z }
end

function Stops.itemPos(id: number): Vector3?
	local e = entries[id]
	return if e then e.body.Position else nil
end

-- Where a player who joins during a stop appears: on the platform at the train door (GDD I4).
function Stops.platform(n: number): CFrame?
	if site == nil then
		return nil
	end
	return site * CFrame.new((n % 6 - 2.5) * 4, LanternConfig.TILE_DECK.height + 3, 5) * CFrame.Angles(0, math.pi, 0)
end

return Stops
