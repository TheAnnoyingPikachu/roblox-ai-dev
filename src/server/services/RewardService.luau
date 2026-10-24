--!strict
-- Owns coin balances for the session. Clients fire RequestClaim; this service
-- validates, applies RewardRules, and replicates the result through leaderstats.
-- Persistence (DataStore) is added in M3 behind its own service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RewardRules = require(Shared:WaitForChild("RewardRules"))

local RewardService = {}

local states: { [Player]: RewardRules.PlayerState } = {}

local function setupLeaderstats(player: Player): IntValue
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats
	leaderstats.Parent = player
	return coins
end

local function onClaim(player: Player, payload: any)
	local state = states[player]
	if state == nil then
		return
	end

	local valid, reason = RewardRules.validateRequest(payload, Config.AllowedRewardSources)
	if not valid then
		warn(`[RewardService] rejected request from {player.UserId}: {reason}`)
		return
	end

	local result = RewardRules.claim(state, os.clock(), Config.Reward)
	if not result.ok then
		return
	end

	states[player] = result.state
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value = result.state.coins
	end
end

function RewardService.start(remotes: Folder)
	local requestClaim = Instance.new("RemoteEvent")
	requestClaim.Name = "RequestClaim"
	requestClaim.Parent = remotes
	requestClaim.OnServerEvent:Connect(onClaim)

	local function onPlayerAdded(player: Player)
		states[player] = RewardRules.newState(os.clock())
		setupLeaderstats(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return RewardService
