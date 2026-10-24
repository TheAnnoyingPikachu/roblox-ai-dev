--!strict
-- Server authority for Bake Rush. Clients send Bake, Sell and Upgrade requests with no
-- values; the server applies BakeRules and replicates the result through leaderstats.
-- Saves are added in PILOT-004 behind their own service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BakeConfig = require(Shared:WaitForChild("BakeConfig"))
local BakeRules = require(Shared:WaitForChild("BakeRules"))

local BakeService = {}

local states: { [Player]: BakeRules.State } = {}

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Coins", "Tier", "Pastries" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function publish(player: Player, state: BakeRules.State)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end
	local function set(name: string, value: number)
		local v = leaderstats:FindFirstChild(name)
		if v and v:IsA("IntValue") then
			v.Value = value
		end
	end
	set("Coins", state.coins)
	set("Tier", state.tier)
	set("Pastries", state.pastries)
end

local function handle(player: Player, action: (BakeRules.State) -> BakeRules.Outcome)
	local state = states[player]
	if state == nil then
		return
	end
	local result = action(state)
	states[player] = result.state
	publish(player, result.state)
end

function BakeService.start(remotes: Folder)
	local bake = Instance.new("RemoteEvent")
	bake.Name = "Bake"
	bake.Parent = remotes
	local sell = Instance.new("RemoteEvent")
	sell.Name = "Sell"
	sell.Parent = remotes
	local upgrade = Instance.new("RemoteEvent")
	upgrade.Name = "Upgrade"
	upgrade.Parent = remotes

	bake.OnServerEvent:Connect(function(player: Player)
		handle(player, function(state)
			return BakeRules.bake(state, os.clock(), BakeConfig)
		end)
	end)
	sell.OnServerEvent:Connect(function(player: Player)
		handle(player, function(state)
			return BakeRules.sell(state, BakeConfig)
		end)
	end)
	upgrade.OnServerEvent:Connect(function(player: Player)
		handle(player, function(state)
			return BakeRules.upgrade(state, BakeConfig)
		end)
	end)

	local function onPlayerAdded(player: Player)
		states[player] = BakeRules.newState()
		setupLeaderstats(player)
		publish(player, states[player])
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return BakeService
