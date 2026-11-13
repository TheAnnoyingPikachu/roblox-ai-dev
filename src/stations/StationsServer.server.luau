--!strict
-- Animal Stations server entry: builds the world and gives each player a home ranch (lowest free of
-- World.RANCHES). Owners spawn at their ranch gate; the hub plaza is the shared space. Saves, eggs
-- and stations come next.
local Players = game:GetService("Players")

local World = require(script.Parent:WaitForChild("World"))

World.build()

-- Max Players is a place setting a place file cannot carry: set it to 6 when publishing.
if Players.MaxPlayers > World.RANCHES then
	warn(`[StationsServer] Max Players {Players.MaxPlayers} is above the {World.RANCHES} ranches`)
end

local owners: { [number]: Player } = {}

local function ranchOf(player: Player): number?
	for i, p in owners do
		if p == player then
			return i
		end
	end
	return nil
end

local function toRanch(player: Player)
	local i = ranchOf(player)
	if i and player.Character then
		player.Character:PivotTo(World.ranchSpawn(i))
	end
end

local function join(player: Player)
	for i = 1, World.RANCHES do
		if owners[i] == nil then
			owners[i] = player
			player:SetAttribute("Ranch", i)
			World.setRanchOwner(i, player)
			break
		end
	end
	-- no free ranch (only when Max Players is above 6): the player stays at the hub spawn
	local function spawned(character: Model)
		character:WaitForChild("HumanoidRootPart")
		task.wait() -- the SpawnLocation places the character after CharacterAdded; move it after that
		toRanch(player)
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		task.spawn(spawned, player.Character)
	end
end

Players.PlayerAdded:Connect(join)
for _, p in Players:GetPlayers() do
	join(p)
end

Players.PlayerRemoving:Connect(function(player)
	local i = ranchOf(player)
	if i then
		owners[i] = nil
		World.setRanchOwner(i, nil)
	end
end)
