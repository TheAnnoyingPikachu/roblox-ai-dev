--!strict
-- Hundred Demon Night player profiles (decision 0007), copied from src/relay/Profiles.luau.
-- Loads and saves with DataStoreService and applies every change through NightProgress.
--
-- Every write is an UpdateAsync whose transform re-reads the stored record and applies the same
-- pure change to it, so a failed or late load can never write defaults over saved progress.
-- If DataStores are unavailable (Studio without API access), the session keeps an in-memory
-- profile, writes nothing and says so. There is no remote here: NightServer's router runs the
-- common request checks and calls Profiles.request only after they pass.
--
-- Writes are queued per player (QA M2, m1, m7, m9): a change that leaves the profile identical is
-- neither written nor published; changes made while a write is waiting or in flight join the next
-- one; one player's key is written at most once per WRITE_GAP; a write that fails 3 times keeps
-- its changes for the next write; BindToClose waits for the queue to drain.

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
local WRITE_GAP = 6 -- the same-key write limit; also caps a player at 10 writes a minute
local CLOSE_WAIT = 25

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

type Change = (Profile) -> Profile
type Session = { profile: Profile, online: boolean, pending: { Change }, writing: boolean, lastWrite: number }
local sessions: { [Player]: Session } = {}
local writers = 0 -- sessions with a write queued or in flight
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

-- A key-order-independent encoding, so two equal profiles always compare equal.
local function canonical(value: any): string
	if type(value) ~= "table" then
		return `{typeof(value)}:{tostring(value)}`
	end
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return canonical(a) < canonical(b)
	end)
	local parts = table.create(#keys)
	for _, key in keys do
		table.insert(parts, `{canonical(key)}={canonical(value[key])}`)
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function replay(profile: Profile, changes: { Change }): Profile
	for _, change in changes do
		profile = change(profile)
	end
	return profile
end

-- Drains the session's queue, one UpdateAsync per batch.
local function drain(player: Player, session: Session)
	while #session.pending > 0 do
		local gap = session.lastWrite + WRITE_GAP - os.clock()
		if gap > 0 then
			task.wait(gap) -- changes made meanwhile join this batch
		end
		local batch = session.pending
		session.pending = {}
		session.lastWrite = os.clock()
		local ok, stored = withRetries(`save {player.UserId}`, function()
			return (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
				return replay(NightProgress.sanitize(old), batch)
			end)
		end)
		if not ok then
			-- Keep the batch ahead of newer changes; the next write re-applies it (QA m1).
			session.pending = table.move(session.pending, 1, #session.pending, #batch + 1, batch)
			warn(`[Profiles] {#batch} change(s) for {player.UserId} not saved yet; retrying with the next write`)
			break
		end
		if stored and sessions[player] == session then
			-- The stored copy is the truth; adopt it, with changes still queued on top.
			local profile = replay(NightProgress.sanitize(stored), session.pending)
			if canonical(profile) ~= canonical(session.profile) then
				session.profile = profile
				publish(player, profile)
			end
		end
	end
	session.writing = false
	writers -= 1
end

local function flush(player: Player, session: Session)
	if session.online and not session.writing and #session.pending > 0 then
		session.writing = true
		writers += 1
		-- Deferred, so changes made in the same frame (the wave-10 clear and Victory) share a write.
		task.defer(drain, player, session)
	end
end

-- Applies `change` to the in-memory profile now and queues it for the stored record.
-- `change` must be pure: the same function runs on the stored copy inside UpdateAsync.
local function apply(player: Player, change: Change)
	local session = sessions[player]
	if session == nil then
		return
	end
	local updated = change(session.profile)
	if canonical(updated) == canonical(session.profile) then
		return -- no-op (equipping what is worn, the current tier): nothing to write (QA M2)
	end
	session.profile = updated
	publish(player, updated)
	if session.online then
		table.insert(session.pending, change)
		flush(player, session)
	end
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
	local session: Session =
		{ profile = NightProgress.defaults(), online = false, pending = {}, writing = false, lastWrite = -math.huge }
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
	publish(player, session.profile)
	local day = today()
	apply(player, function(p)
		return NightProgress.login(p, day)
	end)
end

-- Queued changes are still written after release (the drain holds the session).
function Profiles.release(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		flush(player, session)
	end
end

-- Pending writes would be cut off by a shutdown (QA m7).
game:BindToClose(function()
	for player, session in sessions do
		flush(player, session)
	end
	local deadline = os.clock() + CLOSE_WAIT
	while writers > 0 and os.clock() < deadline do
		task.wait(0.5)
	end
end)

-- Called at each wave clear for every participant (downed included).
function Profiles.recordWave(player: Player, result: NightProgress.WaveResult)
	local session = sessions[player]
	if session == nil then
		return
	end
	local day = today()
	local _, xp, souls = NightProgress.applyWave(session.profile, result, day)
	player:SetAttribute("LastReward", `+{xp} XP  +{souls} souls`)
	apply(player, function(p)
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
	apply(player, function(p)
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
		apply(player, function(p)
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
