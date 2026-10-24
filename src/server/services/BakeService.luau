--!strict
-- Server authority for Bake Rush. Players use ProximityPrompts on three stations, which work
-- on PC, mobile and console. The server applies BakeRules to every request.
-- SaveService owns when a player's state is stored and released (see decision 0005).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BakeConfig = require(Shared:WaitForChild("BakeConfig"))
local BakeRules = require(Shared:WaitForChild("BakeRules"))

type Stats = {
	state: BakeRules.State,
	ready: boolean,
	coins: IntValue,
	tier: IntValue,
	pastries: IntValue,
}

local BakeService = {}

local players: { [Player]: Stats } = {}

local function makeStation(folder: Folder, name: string, position: Vector3, actionText: string): ProximityPrompt
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(6, 3, 6)
	part.Position = position
	part.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = name
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function createStations(): { [string]: ProximityPrompt }
	local folder = Instance.new("Folder")
	folder.Name = "BakeRush"
	folder.Parent = Workspace
	return {
		bake = makeStation(folder, "Oven", Vector3.new(0, 1.5, 20), "Bake"),
		sell = makeStation(folder, "Counter", Vector3.new(12, 1.5, 20), "Sell"),
		upgrade = makeStation(folder, "UpgradeStation", Vector3.new(-12, 1.5, 20), "Upgrade"),
	}
end

local function createStats(player: Player): Stats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local function value(name: string): IntValue
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = leaderstats
		return v
	end

	local stats: Stats = {
		state = BakeRules.newState(),
		ready = false,
		coins = value("Coins"),
		tier = value("Tier"),
		pastries = value("Pastries"),
	}
	stats.tier.Value = stats.state.tier
	leaderstats.Parent = player
	return stats
end

local function publish(stats: Stats)
	stats.coins.Value = stats.state.coins
	stats.tier.Value = stats.state.tier
	stats.pastries.Value = stats.state.pastries
end

local function apply(player: Player, action: (BakeRules.State) -> BakeRules.Outcome)
	local stats = players[player]
	if stats == nil or not stats.ready then
		return
	end
	local result = action(stats.state)
	stats.state = result.state
	publish(stats)
end

-- Called by SaveService once a player's load has finished. Actions are ignored until then,
-- so a player can't bake over saved progress.
function BakeService.restore(player: Player, state: BakeRules.State)
	local stats = players[player]
	if stats == nil then
		warn(`[BakeService] restore called for a player with no stats: {player.UserId}`)
		return
	end
	stats.state = state
	stats.ready = true
	publish(stats)
end

-- Returns the current state for saving, or nil if the player isn't ready.
function BakeService.getState(player: Player): BakeRules.State?
	local stats = players[player]
	if stats == nil or not stats.ready then
		return nil
	end
	return stats.state
end

-- Drops a player's state. Called by SaveService after the final save, so BakeService never
-- clears state before it has been saved.
function BakeService.release(player: Player)
	players[player] = nil
end

function BakeService.start()
	local prompts = createStations()

	prompts.bake.Triggered:Connect(function(player: Player)
		apply(player, function(state)
			return BakeRules.bake(state, time(), BakeConfig)
		end)
	end)
	prompts.sell.Triggered:Connect(function(player: Player)
		apply(player, function(state)
			return BakeRules.sell(state, BakeConfig)
		end)
	end)
	prompts.upgrade.Triggered:Connect(function(player: Player)
		apply(player, function(state)
			return BakeRules.upgrade(state, BakeConfig)
		end)
	end)

	local function onPlayerAdded(player: Player)
		players[player] = createStats(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return BakeService
