--!strict
-- Loads and saves each player's Bake Rush progress with DataStoreService.
-- Rules (see docs/decisions/0005-bake-rush-save-data.md):
--   * Every write is an UpdateAsync that takes or checks a session lock and a save count.
--     A server never overwrites a record another server has taken over or a newer save.
--   * A load that finds a fresh lock held by another server kicks the player. A failed load
--     kicks the player too. Saving is off for that session, so defaults never overwrite data.
--   * Saves run on leave, on server close and every 60 seconds, never per action.
--   * Leave and shutdown share one finalize path, so no player is saved twice at the end.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BakeRules = require(Shared:WaitForChild("BakeRules"))
local SaveRules = require(Shared:WaitForChild("SaveRules"))

local SaveService = {}

-- Set to the production universe ID before the first production release (decision 0005).
-- Until it is set, live servers use the staging store, which is the safe default.
local PRODUCTION_UNIVERSE_ID: number? = nil

local SAVE_INTERVAL = 60
local MAX_ATTEMPTS = 3
local SHUTDOWN_DEADLINE = 25

local function storeName(): string
	if RunService:IsStudio() then
		return "BakeRushSave_studio"
	end
	if PRODUCTION_UNIVERSE_ID ~= nil and game.GameId == PRODUCTION_UNIVERSE_ID then
		return "BakeRushSave"
	end
	return "BakeRushSave_staging"
end

local store = DataStoreService:GetDataStore(storeName())

type Session = {
	saveEnabled: boolean,
	saveCount: number,
	finalizing: boolean,
	saving: boolean,
}

local sessions: { [Player]: Session } = {}
local inFlight = 0
-- Set by start(). Reads the player's live gameplay state for a save.
local readState: (Player) -> BakeRules.State? = function(_player: Player)
	return nil
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

-- Retries with exponential backoff. Returns true and the result on success.
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

-- Writes the player's state. Returns "written", "rejected" (another server owns the record),
-- or "failed" (retries exhausted; stored data is unchanged).
local function writeState(player: Player, state: BakeRules.State, session: Session, releaseLock: boolean): string
	local jobId = game.JobId
	local now = os.time()
	local outcome = "rejected"

	local ok = withRetries(`save {player.UserId}`, function()
		store:UpdateAsync(keyFor(player), function(existing: any)
			-- The transform can run more than once per call, so reset the outcome each time.
			outcome = "rejected"
			local current = if existing ~= nil then SaveRules.sanitize(existing) else nil
			if SaveRules.decideWrite(current, jobId, session.saveCount) == "reject" then
				return nil
			end
			outcome = "written"
			local lock = if releaseLock then nil else { jobId = jobId, at = now }
			return SaveRules.fromState(state, session.saveCount + 1, lock)
		end)
		return outcome
	end)

	if not ok then
		return "failed"
	end
	return outcome
end

-- Saves for one player never overlap. Autosave skips a busy session; the final save waits its turn.
local function saveNow(player: Player, releaseLock: boolean)
	local session = sessions[player]
	if session == nil or not session.saveEnabled then
		return
	end
	if not releaseLock and session.saving then
		return
	end
	while session.saving do
		task.wait(0.1)
	end
	session.saving = true

	-- Re-check after waiting: a rejection or a finished teardown may have happened meanwhile.
	if not session.saveEnabled or (session.finalizing and not releaseLock) then
		session.saving = false
		return
	end
	local state = readState(player)
	if state == nil then
		session.saving = false
		warn(`[SaveService] skipped save for {player.UserId}: no state to save`)
		return
	end

	local result = writeState(player, state, session, releaseLock)
	session.saving = false
	if result == "written" then
		session.saveCount += 1
	elseif result == "rejected" then
		session.saveEnabled = false
		warn(`[SaveService] save rejected for {player.UserId}: another server owns this record`)
		if player.Parent ~= nil then
			player:Kick("Your progress was updated on another server. Please rejoin.")
		end
	else
		warn(`[SaveService] giving up on save for {player.UserId}; stored data is unchanged`)
	end
end

-- The one teardown path for leave and shutdown. Safe to call twice.
local function finalize(player: Player, release: (Player) -> ())
	local session = sessions[player]
	if session == nil or session.finalizing then
		return
	end
	session.finalizing = true
	inFlight += 1
	saveNow(player, true)
	release(player)
	sessions[player] = nil
	inFlight -= 1
end

local function loadPlayer(player: Player, session: Session, restore: (Player, BakeRules.State) -> ())
	local jobId = game.JobId
	local now = os.time()
	local locked = false

	local ok, record = withRetries(`load {player.UserId}`, function()
		return store:UpdateAsync(keyFor(player), function(existing: any)
			-- The transform can run more than once per call, so reset the flag each time.
			locked = false
			local current = if existing ~= nil then SaveRules.sanitize(existing) else nil
			if SaveRules.decideClaim(current, jobId, now) == "locked" then
				locked = true
				return nil
			end
			local base = current or SaveRules.defaults()
			return SaveRules.fromState(base, base.saveCount, { jobId = jobId, at = now })
		end)
	end)

	if player.Parent == nil then
		return
	end
	if not ok then
		warn(`[SaveService] load failed for {player.UserId}; kicking so progress is not lost silently`)
		player:Kick("We couldn't load your progress. Please rejoin.")
		return
	end
	if locked or record == nil then
		player:Kick("Your progress is open on another server. Please rejoin in a few minutes.")
		return
	end

	session.saveCount = record.saveCount
	session.saveEnabled = true
	restore(player, SaveRules.toState(SaveRules.sanitize(record)))
end

function SaveService.start(
	restore: (Player, BakeRules.State) -> (),
	getState: (Player) -> BakeRules.State?,
	release: (Player) -> ()
)
	readState = getState

	local function onPlayerAdded(player: Player)
		local session: Session = { saveEnabled = false, saveCount = 0, finalizing = false, saving = false }
		sessions[player] = session
		task.spawn(loadPlayer, player, session, restore)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		task.spawn(finalize, player, release)
	end)

	game:BindToClose(function()
		local deadline = os.clock() + SHUTDOWN_DEADLINE
		local players = {}
		for player in sessions do
			table.insert(players, player)
		end
		for _, player in players do
			task.spawn(finalize, player, release)
		end
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.5)
		end
		if inFlight > 0 then
			warn(`[SaveService] shutdown deadline reached with {inFlight} save(s) still running`)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for player, session in sessions do
				if session.saveEnabled and not session.finalizing then
					task.spawn(saveNow, player, false)
				end
			end
		end
	end)
end

return SaveService
