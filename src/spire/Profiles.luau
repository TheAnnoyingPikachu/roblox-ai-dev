--!strict
-- Neon Spire player profiles (decision 0009), copied from src/garden/Profiles.luau
-- (docs/architecture/spire.md 4.2). Loads and saves with DataStoreService and applies every change
-- through the pure Spire modules.
--
-- Every change runs on the in-memory profile at once and is queued. A flush runs the queued changes,
-- in order, inside one UpdateAsync on the re-read, sanitised stored record and ends with a snapshot
-- (lastSeen), so a failed or late load can never write defaults over saved progress and every
-- stored record is self-consistent. A flush is due when a non-earn change is queued and 7 s have
-- passed since the last write, or after 60 s (autosave); final write on leave and in BindToClose.
-- Online income is credited through merged earn ops (no unbanked pool, no absolute credit snapshot:
-- spire.md 10.3). Without DataStore access or the lock the session plays unsaved and says so.
--
-- Session lock: the load claims `lock = { session, at }` on the record and every write refreshes it;
-- the final write clears it. A load that finds another session's fresh lock retries, then runs
-- offline. A write that finds the lock gone or taken writes nothing and the session goes offline.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SpireConfig = require(Shared:WaitForChild("SpireConfig"))
local SpireProgress = require(Shared:WaitForChild("SpireProgress"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Profile = SpireConfig.Profile
type Change = (Profile) -> Profile

local Profiles = {}

-- Set to the production universe ID before the first production release, with SHANNON's approval.
local PRODUCTION_UNIVERSE_ID: number? = nil
local MAX_ATTEMPTS = 3
local COALESCE = 7 -- seconds between writes while a non-earn change is queued (decision 0009)
local AUTOSAVE = 60
local BOARD_EVERY = 120
local BOARD_MAX = 2 ^ 53 -- exact integers in Luau numbers (spire.md 10.13)
local CLOSE_BUDGET = 25 -- BindToClose has 30 s
local INFLIGHT_WAIT = 10 -- leave: longest wait for a running write before the final one
local OFFLINE_TEXT = "Saving is offline on this server: progress here lasts this session only."
local BUSY_TEXT = "Your tower is still saving on another server, so this visit is not saved. Rejoin in a minute."

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
	return DataStoreService:GetDataStore("SpireProfile" .. storeSuffix())
end)
local okBoard, board = pcall(function()
	return DataStoreService:GetOrderedDataStore("SpireBoard" .. storeSuffix())
end)

type Earn = { credits: number, seconds: number, today: number, op: Change }
type Session = {
	id: string, -- lock owner: one GUID per load
	profile: Profile,
	online: boolean,
	queue: { Change },
	urgent: boolean, -- a non-earn change is queued (makes the 7 s flush due)
	earn: Earn?, -- the merged earn op while it is the last queued change
	writing: boolean,
	lastWrite: number,
	dirty: boolean,
	closing: boolean,
}
local sessions: { [Player]: Session } = {}
local changed = Instance.new("BindableEvent")
Profiles.Changed = changed.Event -- (player, profile)

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

-- deadline (os.clock): no retry wait that would end after it (BindToClose budget).
local function withRetries(label: string, operation: () -> any, deadline: number?): (boolean, any)
	local lastError: any = nil
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[Profiles] {label} attempt {attempt} failed: {tostring(result)}`)
		if attempt == MAX_ATTEMPTS or (deadline and os.clock() + 2 ^ attempt > deadline) then
			break
		end
		task.wait(2 ^ attempt)
	end
	return false, lastError
end

-- Mirrors the profile onto the player for the client UI and the leaderboard. Income is set by the
-- server loop (it depends on the Market event).
local function publish(player: Player, profile: Profile)
	player:SetAttribute("Profile", HttpService:JSONEncode(profile))
	player:SetAttribute("Credits", profile.coins)
	player:SetAttribute("Floors", #profile.floors)
	player:SetAttribute("Level", SpireProgress.levelFor(profile.xp))
	player:SetAttribute("XP", profile.xp)
	local live = State.live[player]
	if live then
		player:SetAttribute("Lot", live.lot)
	end
	local stats = player:FindFirstChild("leaderstats")
	local floors = stats and stats:FindFirstChild("Floors") :: IntValue?
	if floors then
		floors.Value = #profile.floors
	end
	changed:Fire(player, profile)
end

-- One UpdateAsync: re-read and sanitise the stored record, run the queued changes in order, then
-- the snapshot. On success the stored result becomes the in-memory profile, with every change
-- queued since the flush started re-run on it (income credited during the yield sits in a new earn
-- op, so it is kept). On failure the changes go back to the front. Writes only while this session
-- holds the lock; `final` releases it.
local function flush(player: Player, session: Session, now: number, final: boolean?, deadline: number?)
	session.writing = true
	session.lastWrite = now
	local ops, urgent = session.queue, session.urgent
	session.queue, session.urgent = {}, false
	local lost = false
	local ok, stored = withRetries(`flush {player.UserId}`, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
			lost = not SpireProgress.holds(old, session.id)
			if lost then
				return nil -- another server took the record, or this session already released it
			end
			local p = SpireProgress.sanitize(old, now)
			for _, op in ops do
				p = op(p)
			end
			return SpireProgress.locked(SpireProgress.snapshot(p, now), if final then nil else session.id, now)
		end)
	end, deadline)
	if lost then
		-- Never write this profile from here again; the player keeps playing unsaved.
		warn(`[Profiles] {player.UserId} lost the session lock; saving is off for this session`)
		session.online = false
		session.queue, session.urgent = {}, false
		if not session.closing then
			player:SetAttribute("ProfileOnline", false)
			Remotes.notice(player, OFFLINE_TEXT)
		end
	elseif ok and stored ~= nil then
		local p = SpireProgress.sanitize(stored, now)
		for _, op in session.queue do
			p = op(p)
		end
		session.profile = p
		session.dirty = true
	else
		for i, op in ops do
			table.insert(session.queue, i, op)
		end
		session.urgent = session.urgent or urgent
	end
	session.writing = false
end

-- Applies `change` to the in-memory profile now and queues it for the store. `change` must be pure
-- and capture its own now/today/event: the same function runs on the stored copy inside UpdateAsync.
function Profiles.apply(player: Player, label: string, change: Change)
	local session = sessions[player]
	if session == nil then
		return
	end
	local ok, result = pcall(change, session.profile)
	if not ok then
		warn(`[Profiles] {label} failed: {tostring(result)}`)
		return
	end
	session.profile = result
	if session.online then
		table.insert(session.queue, change)
		session.urgent = true
	end
	publish(player, session.profile)
end
local apply = Profiles.apply

-- Online income (1 Hz). Earns in a row on the same day merge into one queued op, so a long
-- DataStore outage queues one op, not one a second, and earn ops alone wait for the 60 s autosave.
-- Only `Credits` is published now; the full profile goes out with the next other change or write.
function Profiles.earn(player: Player, credits: number, seconds: number, today: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.profile = SpireProgress.earn(session.profile, credits, seconds, today)
	player:SetAttribute("Credits", session.profile.coins)
	if not session.online then
		return
	end
	local merged = session.earn
	if merged and merged.today == today and session.queue[#session.queue] == merged.op then
		merged.credits += credits
		merged.seconds += seconds
		return
	end
	local e: Earn = { credits = credits, seconds = seconds, today = today, op = nil :: any }
	e.op = function(p)
		return SpireProgress.earn(p, e.credits, e.seconds, e.today)
	end
	session.earn = e
	table.insert(session.queue, e.op)
end

function Profiles.get(player: Player): Profile?
	local session = sessions[player]
	return session and session.profile
end

function Profiles.isOnline(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.online
end

-- Blocks until loaded. The first operation is login (offline payout).
function Profiles.load(player: Player)
	local now = os.time()
	-- Names a new record's company; drawn once so every retry of the load names it the same.
	local seed = Random.new():NextInteger(1, 2 ^ 31 - 1)
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		profile = SpireProgress.defaults(now, seed),
		online = false,
		queue = {},
		urgent = false,
		writing = false,
		lastWrite = 0, -- the login op is written on the first step
		dirty = false,
		closing = false,
	}
	local busy = false
	if okStore then
		-- Claims the lock (3 tries, 2 s and 4 s apart, so an old server's final write can land first).
		local ok, record = withRetries(`load {player.UserId}`, function()
			local stored = (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
				busy = not SpireProgress.canClaim(old, session.id, now)
				if busy then
					return nil
				end
				return SpireProgress.locked(SpireProgress.sanitize(old, now, seed), session.id, now)
			end)
			if busy then
				error("profile is locked by another server")
			end
			return stored
		end)
		if ok then
			session.online = true
			session.profile = SpireProgress.sanitize(record, now, seed)
		end
	end
	-- The session exists only once loading has finished, so no request runs on a half-loaded profile.
	sessions[player] = session
	player:SetAttribute("ProfileOnline", session.online)
	local _, offline = SpireProgress.login(session.profile, now)
	player:SetAttribute("OfflineCredits", offline)
	apply(player, "login", function(p)
		return (SpireProgress.login(p, now))
	end)
	if player.Parent == nil then
		-- Left while loading (SpireServer's leave found no session): write the login, release the lock.
		Profiles.finish(player, os.time())
		return
	end
	if not session.online then
		Remotes.notice(player, if busy then BUSY_TEXT else OFFLINE_TEXT)
	end
	-- Decision 0009 estimates about 8 KB for a maxed record (limit 12 KB); this logs the real size.
	print(`[Profiles] {player.UserId} loaded ({#HttpService:JSONEncode(session.profile)} bytes encoded)`)
end

-- A Request action after SpireServer's common and world checks. SpireProgress.apply decides on the
-- in-memory profile first; only an accepted change is applied and queued, with the same now and
-- event, so a refused request changes and queues nothing.
function Profiles.request(player: Player, action: string, arg: string?, event: string): (boolean, string?)
	local session = sessions[player]
	if session == nil or session.closing then
		return false, "busy"
	end
	local now = os.time()
	local _, ok, code = SpireProgress.apply(session.profile, action, arg, now, event)
	if not ok then
		return false, code
	end
	apply(player, action, function(p)
		return (SpireProgress.apply(p, action, arg, now, event))
	end)
	return true
end

-- 1 Hz: publish dirty sessions, flush due queues, write changed lifetime earnings to the board.
function Profiles.step(now: number)
	for player, session in sessions do
		if session.closing then
			continue
		end
		if session.dirty then
			session.dirty = false
			publish(player, session.profile)
		end
		if not session.online then
			continue
		end
		local since = now - session.lastWrite
		if not session.writing and ((session.urgent and since >= COALESCE) or since >= AUTOSAVE) then
			task.spawn(flush, player, session, now)
		end
		local live = State.live[player]
		if live and okBoard then
			local earned = math.min(math.floor(session.profile.lifetimeEarned), BOARD_MAX)
			if earned ~= live.boardEarned and now - live.boardAt >= BOARD_EVERY then
				live.boardEarned = earned
				live.boardAt = now
				local key = keyFor(player)
				task.spawn(function()
					pcall(function()
						(board :: OrderedDataStore):SetAsync(key, earned)
					end)
				end)
			end
		end
	end
end

-- Leave (GDD P): queues the leave op (lastSeen = now), waits for any running flush, writes once more
-- releasing the lock and drops the session.
function Profiles.finish(player: Player, now: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	if session.closing then
		-- PlayerRemoving and BindToClose can both arrive; the second waits for the first.
		local started = os.clock()
		while sessions[player] == session and os.clock() - started < CLOSE_BUDGET do
			task.wait(0.1)
		end
		return
	end
	-- One budget from the start: at most INFLIGHT_WAIT for a running write, no retry wait past it.
	local started = os.clock()
	if session.online then
		apply(player, "leave", function(p)
			return SpireProgress.snapshot(p, now)
		end)
		session.closing = true
		while session.writing and os.clock() - started < INFLIGHT_WAIT do
			task.wait(0.1)
		end
		if session.online then -- a running write may have lost the lock
			flush(player, session, now, true, started + CLOSE_BUDGET)
		end
	end
	session.closing = true
	if sessions[player] == session then
		sessions[player] = nil
	end
end

-- BindToClose: every session in parallel, within the 30 s budget.
function Profiles.finishAll(now: number)
	local pending = 0
	for player in sessions do
		pending += 1
		task.spawn(function()
			Profiles.finish(player, now)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < CLOSE_BUDGET + 2 do
		task.wait(0.1)
	end
end

-- Top Spires board ------------------------------------------------------------------------------

-- Top 10 as { name, earned }. Empty if the ordered store is unavailable.
function Profiles.topEarned(): { { name: string, earned: number } }
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
		table.insert(rows, { name = name, earned = entry.value })
	end
	return rows
end

return Profiles
