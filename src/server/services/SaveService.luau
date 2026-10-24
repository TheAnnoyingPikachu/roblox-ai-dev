--!strict
-- Loads and saves each player's Bake Rush progress with DataStoreService.
-- Safety rules:
--   * Players are only restored after a successful load, or after a failed load that
--     disables saving for that session. A failed load never writes defaults over real data.
--   * Saves run on leave, on server close and every 60 seconds, never per action.
--   * Saves retry with backoff and log on failure. A failed save never clears saved data.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BakeConfig = require(Shared:WaitForChild("BakeConfig"))
local BakeRules = require(Shared:WaitForChild("BakeRules"))
local SaveRules = require(Shared:WaitForChild("SaveRules"))

local SaveService = {}

local STORE_NAME = "BakeRushSave"
local SAVE_INTERVAL = 60
local MAX_ATTEMPTS = 3

type Session = {
	saveEnabled: boolean,
}

local store = DataStoreService:GetDataStore(STORE_NAME)
local sessions: { [Player]: Session } = {}

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

-- Retries with exponential backoff. Returns true and the value on success.
local function withRetries(label: string, operation: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[SaveService] {label} attempt {attempt} failed: {tostring(result)}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

local function savePlayer(player: Player, getState: (Player) -> BakeRules.State?, saveSession: Session)
	if not saveSession.saveEnabled then
		return
	end
	local state = getState(player)
	if state == nil then
		return
	end
	local record = SaveRules.fromState(state)
	local ok = withRetries(`save {player.UserId}`, function()
		store:SetAsync(keyFor(player), record)
	end)
	if not ok then
		warn(`[SaveService] giving up on save for {player.UserId}; saved data is unchanged`)
	end
end

function SaveService.start(
	restore: (Player, BakeRules.State) -> (),
	getState: (Player) -> BakeRules.State?
)
	local function onPlayerAdded(player: Player)
		local session: Session = { saveEnabled = false }
		sessions[player] = session

		task.spawn(function()
			local ok, data = withRetries(`load {player.UserId}`, function()
				return store:GetAsync(keyFor(player))
			end)
			if player.Parent == nil then
				sessions[player] = nil
				return
			end
			if ok then
				session.saveEnabled = true
				restore(player, SaveRules.sanitize(data, BakeConfig.maxCoins, #BakeConfig.tiers) :: any)
			else
				warn(`[SaveService] load failed for {player.UserId}; progress will not be saved this session`)
				restore(player, BakeRules.newState())
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			savePlayer(player, getState, session)
		end
		sessions[player] = nil
	end)

	game:BindToClose(function()
		for player, session in sessions do
			savePlayer(player, getState, session)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for player, session in sessions do
				savePlayer(player, getState, session)
			end
		end
	end)
end

return SaveService
