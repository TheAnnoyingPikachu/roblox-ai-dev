--!strict
-- Hundred Demon Night player profiles (decision 0007), copied from src/relay/Profiles.luau.
-- Loads and saves with DataStoreService and applies every change through NightProgress.
--
-- Every write is an UpdateAsync whose transform re-reads the stored record and applies the same
-- pure change to it, so a failed or late load can never write defaults over saved progress.
-- If DataStores are unavailable (Studio without API access), the session keeps an in-memory
-- profile, writes nothing and says so. There is no remote here: NightServer's router runs the
-- common request checks and calls Profiles.request only after they pass.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local NightProgress = require(Shared:WaitForChild("NightProgress"))

type Profile = NightProgress.Profile

local Profiles = {}

-- Set to the production universe ID before the first production release, with SHANNON's approval.
local PRODUCTION_UNIVERSE_ID: number? = nil
local MAX_ATTEMPTS = 3

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
	return DataStoreService:GetDataStore("NightProfile" .. storeSuffix())
end)
local okBoard, board = pcall(function()
	return DataStoreService:GetOrderedDataStore("NightWins" .. storeSuffix())
end)

type Session = { profile: Profile, online: boolean }
local sessions: { [Player]: Session } = {}
local changed = Instance.new("BindableEvent")
Profiles.Changed = changed.Event -- (player, profile)

local function today(): number
	return MetaRules.dayOf(os.time())
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
local function publish(player: Player, profile: Profile)
	local level = NightProgress.levelFor(profile.xp)
	player:SetAttribute("XP", profile.xp)
	player:SetAttribute("Level", level)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Weapon", profile.weapon)
	player:SetAttribute("Blade", profile.blade)
	player:SetAttribute("Mask", profile.mask)
	player:SetAttribute("Profile", HttpService:JSONEncode(profile))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local nights = stats:FindFirstChild("Nights") :: IntValue?
		local levelValue = stats:FindFirstChild("Level") :: IntValue?
		if nights then
			nights.Value = profile.wins
		end
		if levelValue then
			levelValue.Value = level
		end
	end
	changed:Fire(player, profile)
end

-- Applies `change` to the in-memory profile now and to the stored record in the background.
-- `change` must be pure: the same function runs on the stored copy inside UpdateAsync.
local function apply(player: Player, label: string, change: (Profile) -> Profile)
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
				return change(NightProgress.sanitize(old))
			end)
		end)
		if ok and stored and sessions[player] == session then
			-- The stored copy is the truth; adopt it so both agree.
			session.profile = NightProgress.sanitize(stored)
			publish(player, session.profile)
		end
	end)
end

function Profiles.get(player: Player): Profile?
	local session = sessions[player]
	return session and session.profile
end

function Profiles.isOnline(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.online
end

function Profiles.load(player: Player)
	local session: Session = { profile = NightProgress.defaults(), online = false }
	if okStore then
		local ok, record = withRetries(`load {player.UserId}`, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			session.online = true
			session.profile = NightProgress.sanitize(record)
		end
	end
	if player.Parent == nil then
		return
	end
	-- The session exists only once loading has finished, so no request runs on a half-loaded profile.
	sessions[player] = session
	player:SetAttribute("ProfileOnline", session.online)
	local day = today()
	apply(player, "login", function(p)
		return NightProgress.login(p, day)
	end)
end

function Profiles.release(player: Player)
	sessions[player] = nil
end

-- Called at each wave clear for every participant (downed included).
function Profiles.recordWave(player: Player, result: NightProgress.WaveResult)
	local session = sessions[player]
	if session == nil then
		return
	end
	local day = today()
	local _, xp, souls = NightProgress.applyWave(session.profile, result, day)
	player:SetAttribute("LastReward", `+{xp} XP  +{souls} souls`)
	apply(player, "wave", function(p)
		return (NightProgress.applyWave(p, result, day))
	end)
end

-- Called on Victory for every participant; also writes the NightWins board (best effort).
function Profiles.recordVictory(player: Player, tier: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	local day = today()
	local _, xp, souls = NightProgress.applyVictory(session.profile, tier, day)
	player:SetAttribute("LastReward", `Victory! +{xp} XP  +{souls} souls`)
	apply(player, "victory", function(p)
		return (NightProgress.applyVictory(p, tier, day))
	end)
	if session.online and okBoard then
		local wins = session.profile.wins
		task.spawn(function()
			pcall(function()
				(board :: OrderedDataStore):SetAsync(keyFor(player), wins)
			end)
		end)
	end
end

-- Meta requests -----------------------------------------------------------------------------

local TIER_ARGS: { [string]: number } = { ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5 }

local ACTIONS: { [string]: (Profile, number, string?) -> (Profile, boolean) } = {
	claimDaily = function(p, day)
		local next, ok = NightProgress.claimDaily(p, day)
		return next, ok
	end,
	claimWeekly = function(p, day)
		local next, ok = NightProgress.claimWeekly(p, day)
		return next, ok
	end,
	claimQuest = function(p, day, arg)
		if arg == nil then
			return p, false
		end
		local next, ok = NightProgress.claimQuest(p, day, arg)
		return next, ok
	end,
	buyCosmetic = function(p, _, arg)
		if arg == nil then
			return p, false
		end
		return NightProgress.buyCosmetic(p, arg)
	end,
	equipCosmetic = function(p, _, arg)
		if arg == nil then
			return p, false
		end
		return NightProgress.equipCosmetic(p, arg)
	end,
	setTier = function(p, _, arg)
		local tier = arg and TIER_ARGS[arg]
		if tier == nil then
			return p, false
		end
		return NightProgress.setTier(p, tier)
	end,
	equipWeapon = function(p, _, arg)
		if arg == nil then
			return p, false
		end
		return NightProgress.equipWeapon(p, arg)
	end,
}

-- Runs a meta action after NightServer's common checks. The pure rule decides on a copy first;
-- only an accepted change is applied and written.
function Profiles.request(player: Player, action: string, arg: string?): boolean
	local session = sessions[player]
	local handler = ACTIONS[action]
	if session == nil or handler == nil then
		return false
	end
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

-- Global nights-won leaderboard -------------------------------------------------------------

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
