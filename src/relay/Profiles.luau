--!strict
-- Relay Rounds player profiles (decision 0006). Loads and saves with DataStoreService, applies
-- every change through ProgressRules, and answers the client's Request remote.
--
-- Every write is an UpdateAsync whose transform re-reads the stored record and applies the same
-- pure change to it, so a failed or late load can never write defaults over saved progress.
-- If DataStores are unavailable (Studio without API access), the session keeps an in-memory
-- profile and says so; nothing is lost because nothing was loaded.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProgressRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressRules"))

local Profiles = {}

-- Set to the production universe ID before the first production release (decision 0006).
local PRODUCTION_UNIVERSE_ID: number? = nil
local MAX_ATTEMPTS = 3
local REQUEST_COOLDOWN = 0.35

local function storeSuffix(): string
	if RunService:IsStudio() then
		return "_studio"
	end
	if PRODUCTION_UNIVERSE_ID ~= nil and game.GameId == PRODUCTION_UNIVERSE_ID then
		return ""
	end
	return "_staging"
end

local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("RelayProfile" .. storeSuffix())
end)
local okBoard, board = pcall(function()
	return DataStoreService:GetOrderedDataStore("RelayWins" .. storeSuffix())
end)

type Session = { profile: ProgressRules.Profile, online: boolean, lastRequest: number }
local sessions: { [Player]: Session } = {}
local changed = Instance.new("BindableEvent")
Profiles.Changed = changed.Event -- (player, profile)

local function today(): number
	return ProgressRules.dayOf(os.time())
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function withRetries(label: string, operation: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[Profiles] {label} attempt {attempt} failed: {tostring(result)}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

-- Mirrors the profile onto the player for the client UI and the leaderboard columns.
local function publish(player: Player, profile: ProgressRules.Profile)
	player:SetAttribute("XP", profile.xp)
	player:SetAttribute("Level", ProgressRules.levelFor(profile.xp))
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Trail", profile.trail)
	player:SetAttribute("Profile", game:GetService("HttpService"):JSONEncode(profile))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local wins = stats:FindFirstChild("Wins") :: IntValue?
		local level = stats:FindFirstChild("Level") :: IntValue?
		if wins then
			wins.Value = profile.wins
		end
		if level then
			level.Value = ProgressRules.levelFor(profile.xp)
		end
	end
	changed:Fire(player, profile)
end

-- Applies `change` to the in-memory profile now and to the stored record in the background.
-- `change` must be pure: the same function runs on the stored copy inside UpdateAsync.
local function apply(player: Player, label: string, change: (ProgressRules.Profile) -> ProgressRules.Profile)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.profile = change(session.profile)
	publish(player, session.profile)
	if not session.online then
		return
	end
	task.spawn(function()
		local ok, stored = withRetries(`{label} {player.UserId}`, function()
			return (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
				return change(ProgressRules.sanitize(old))
			end)
		end)
		if ok and stored and sessions[player] == session then
			-- The stored copy is the truth; adopt it so both agree.
			session.profile = ProgressRules.sanitize(stored)
			publish(player, session.profile)
		end
	end)
end

function Profiles.get(player: Player): ProgressRules.Profile?
	local session = sessions[player]
	return session and session.profile
end

function Profiles.isOnline(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.online
end

function Profiles.load(player: Player)
	local session: Session = { profile = ProgressRules.defaults(), online = false, lastRequest = 0 }
	sessions[player] = session
	if okStore then
		local ok, record = withRetries(`load {player.UserId}`, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			session.online = true
			session.profile = ProgressRules.sanitize(record)
		end
	end
	if player.Parent == nil then
		return
	end
	player:SetAttribute("ProfileOnline", session.online)
	local day = today()
	apply(player, "login", function(p)
		return ProgressRules.login(p, day)
	end)
end

function Profiles.release(player: Player)
	sessions[player] = nil
end

-- Called by the server at the end of a match for each player who took part.
function Profiles.recordMatch(player: Player, result: ProgressRules.MatchResult)
	local day = today()
	local session = sessions[player]
	if session == nil then
		return
	end
	local _, xp, coins = ProgressRules.applyMatch(session.profile, result, day)
	player:SetAttribute("LastReward", `+{xp} XP  +{coins} coins`)
	apply(player, "match", function(p)
		return (ProgressRules.applyMatch(p, result, day))
	end)
	if result.won and session.online and okBoard then
		task.spawn(function()
			pcall(function()
				(board :: OrderedDataStore):SetAsync(keyFor(player), session.profile.wins)
			end)
		end)
	end
end

-- Client requests ---------------------------------------------------------------------------

local ACTIONS: { [string]: (ProgressRules.Profile, number, any) -> (ProgressRules.Profile, boolean) } = {
	claimDaily = function(p, day)
		local next, ok = ProgressRules.claimDaily(p, day)
		return next, ok
	end,
	claimWeekly = function(p, day)
		local next, ok = ProgressRules.claimWeekly(p, day)
		return next, ok
	end,
	claimQuest = function(p, day, arg)
		local next, ok = ProgressRules.claimQuest(p, day, arg)
		return next, ok
	end,
	buyTrail = function(p, _, arg)
		return ProgressRules.buyTrail(p, arg)
	end,
	equipTrail = function(p, _, arg)
		return ProgressRules.equip(p, arg)
	end,
}

-- Remote contract (decision 0006): Request(action: string, arg: string?) -> (ok: boolean).
-- The server validates everything; the client only names the action and an item or quest id.
local function onRequest(player: Player, action: any, arg: any): boolean
	local session = sessions[player]
	if session == nil or type(action) ~= "string" or (arg ~= nil and (type(arg) ~= "string" or #arg > 32)) then
		return false
	end
	local handler = ACTIONS[action]
	if handler == nil or os.clock() - session.lastRequest < REQUEST_COOLDOWN then
		return false
	end
	session.lastRequest = os.clock()
	local day = today()
	local _, ok = handler(session.profile, day, arg)
	if ok then
		apply(player, action, function(p)
			local next = handler(p, day, arg)
			return next
		end)
	end
	return ok
end

local remotes = Instance.new("Folder")
remotes.Name = "RelayRemotes"
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = remotes
remotes.Parent = ReplicatedStorage
request.OnServerInvoke = onRequest

-- Global wins leaderboard -------------------------------------------------------------------

-- Top 10 as { name, wins }. Empty if the ordered store is unavailable.
function Profiles.topWins(): { { name: string, wins: number } }
	local rows = {}
	if not okBoard then
		return rows
	end
	local ok, pages = pcall(function()
		return (board :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok then
		return rows
	end
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.match(entry.key, "%d+"))
		local name = "?"
		if userId then
			local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			name = if okName then result else "?"
		end
		table.insert(rows, { name = name, wins = entry.value })
	end
	return rows
end

return Profiles
