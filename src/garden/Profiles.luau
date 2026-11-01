--!strict
-- Egg Garden player profiles (decision 0008), copied from src/night/Profiles.luau.
-- Loads and saves with DataStoreService and applies every change through the pure Garden modules.
--
-- Every change runs on the in-memory profile at once and is queued. A flush runs the queued changes,
-- in order, inside one UpdateAsync on the re-read, sanitised stored record and ends with a snapshot
-- (unbanked pad coins, lastSeen), so a failed or late load can never write defaults over saved
-- progress and every stored record is self-consistent. Writes are coalesced to at most one per
-- player per 7 s, with a 60 s autosave, a final write on leave and in BindToClose
-- (docs/architecture/garden.md 4.2). Without DataStore access the session keeps an in-memory profile,
-- writes nothing and says so. GardenServer's router runs the common request checks before
-- Profiles.request.
--
-- Session lock (0008 amendment 2026-10-26): the load claims `lock = { session, at }` on the record
-- and every write refreshes it; the final write clears it. A load that finds another session's
-- fresh lock (GardenProgress.LOCK_STALE) retries, then runs offline. A write that finds the lock
-- gone or taken writes nothing and the session goes offline. Both tell the player.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenProgress = require(Shared:WaitForChild("GardenProgress"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Profile = GardenConfig.Profile
type Change = (Profile) -> Profile

local Profiles = {}

-- Set to the production universe ID before the first production release, with SHANNON's approval.
local PRODUCTION_UNIVERSE_ID: number? = nil
local MAX_ATTEMPTS = 3
local COALESCE = 7 -- seconds between writes while changes are queued (decision 0008)
local AUTOSAVE = 60
local BOARD_EVERY = 120
local CLOSE_BUDGET = 25 -- BindToClose has 30 s
local INFLIGHT_WAIT = 10 -- leave: longest wait for a running write before the final one
local OFFLINE_TEXT = "Saving is offline on this server: progress here lasts this session only."
local BUSY_TEXT = "Your garden is still saving on another server, so this visit is not saved. Rejoin in a minute."
local PRIZE_LOST_TEXT = "Saving stopped on this server before your prize egg was saved: it lasts this visit only."

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
	return DataStoreService:GetDataStore("GardenProfile" .. storeSuffix())
end)
local okBoard, board = pcall(function()
	return DataStoreService:GetOrderedDataStore("GardenIncome" .. storeSuffix())
end)

type Bank = { coins: number, pads: number, today: number, op: Change }
type Session = {
	id: string, -- lock owner: one GUID per load
	profile: Profile,
	online: boolean,
	queue: { Change },
	bank: Bank?, -- the merged bank op while it is the last queued change
	writing: boolean,
	lastWrite: number,
	dirty: boolean,
	closing: boolean,
	prizes: number, -- prize eggs queued but not yet stored, so a lost lock can say so
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

-- Mirrors the profile onto the player for the client UI and the leaderboard columns.
local function publish(player: Player, profile: Profile)
	local income = GardenRules.income(profile)
	player:SetAttribute("Profile", HttpService:JSONEncode(profile))
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Income", income)
	player:SetAttribute("Level", GardenProgress.levelFor(profile.xp))
	player:SetAttribute("XP", profile.xp)
	local live = State.live[player]
	if live then
		player:SetAttribute("Plot", live.plot)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local incomeValue = stats:FindFirstChild("Income") :: StringValue?
		local indexValue = stats:FindFirstChild("Index") :: IntValue?
		if incomeValue then
			incomeValue.Value = GardenRules.short(math.floor(income))
		end
		if indexValue then
			indexValue.Value = #profile.index
		end
	end
	changed:Fire(player, profile)
end

-- One UpdateAsync: re-read and sanitise the stored record, run the queued changes in order, then
-- the snapshot. On success the stored result becomes the in-memory profile, with every change
-- queued since the flush started re-run on it. On failure the changes go back to the front.
-- `ops` and `unbanked` are captured together, before any yield, so they describe the same moment.
-- Writes only while this session holds the lock; `final` releases it.
local function flush(
	player: Player,
	session: Session,
	now: number,
	unbanked: number,
	final: boolean?,
	deadline: number?
)
	session.writing = true
	session.lastWrite = now
	local ops = session.queue
	local prizes = session.prizes
	session.queue = {}
	local lost = false
	local ok, stored = withRetries(`flush {player.UserId}`, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
			lost = not GardenProgress.holds(old, session.id)
			if lost then
				return nil -- another server took the record, or this session already released it
			end
			local p = GardenProgress.sanitize(old, now)
			for _, op in ops do
				p = op(p)
			end
			return GardenProgress.locked(
				GardenProgress.snapshot(p, unbanked, now),
				if final then nil else session.id,
				now
			)
		end)
	end, deadline)
	if lost then
		-- Never write this profile from here again; the player keeps playing unsaved.
		warn(`[Profiles] {player.UserId} lost the session lock; saving is off for this session`)
		session.online = false
		session.queue = {}
		if not session.closing then
			player:SetAttribute("ProfileOnline", false)
			Remotes.notice(player, if session.prizes > 0 then PRIZE_LOST_TEXT else OFFLINE_TEXT)
		end
	elseif ok and stored ~= nil then
		session.prizes -= prizes
		local p = GardenProgress.sanitize(stored, now)
		for _, op in session.queue do
			p = op(p)
		end
		session.profile = p
		session.dirty = true
	else
		for i, op in ops do
			table.insert(session.queue, i, op)
		end
	end
	session.writing = false
end

-- Applies `change` to the in-memory profile now and queues it for the store. `change` must be pure
-- and capture its own now/today: the same function runs on the stored copy inside UpdateAsync.
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
		if label == "dashPrize" then
			session.prizes += 1
		end
	end
	publish(player, session.profile)
end
local apply = Profiles.apply

-- Pad banking (5 Hz). Banks in a row on the same day merge into one queued op, so a long DataStore
-- outage queues one op, not five a second. Only `Coins` is published now; the full profile goes
-- out with the next other change or write.
function Profiles.bank(player: Player, coins: number, pads: number, today: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.profile = GardenProgress.bank(session.profile, coins, pads, today)
	player:SetAttribute("Coins", session.profile.coins)
	if not session.online then
		return
	end
	local merged = session.bank
	if merged and merged.today == today and session.queue[#session.queue] == merged.op then
		merged.coins += coins
		merged.pads += pads
		return
	end
	local b: Bank = { coins = coins, pads = pads, today = today, op = nil :: any }
	b.op = function(p)
		return GardenProgress.bank(p, b.coins, b.pads, b.today)
	end
	session.bank = b
	table.insert(session.queue, b.op)
end

function Profiles.get(player: Player): Profile?
	local session = sessions[player]
	return session and session.profile
end

function Profiles.isOnline(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.online
end

-- Blocks until loaded. The first operation is login (unbanked then offline payout).
function Profiles.load(player: Player)
	local now = os.time()
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		profile = GardenProgress.defaults(now),
		online = false,
		queue = {},
		writing = false,
		lastWrite = 0, -- the login op is written on the first step
		dirty = false,
		closing = false,
		prizes = 0,
	}
	local busy = false
	if okStore then
		-- Claims the lock (3 tries, 2 s and 4 s apart, so an old server's final write can land first).
		local ok, record = withRetries(`load {player.UserId}`, function()
			local stored = (store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
				busy = not GardenProgress.canClaim(old, session.id, now)
				if busy then
					return nil
				end
				return GardenProgress.locked(GardenProgress.sanitize(old, now), session.id, now)
			end)
			if busy then
				error("profile is locked by another server")
			end
			return stored
		end)
		if ok then
			session.online = true
			session.profile = GardenProgress.sanitize(record, now)
		end
	end
	-- The session exists only once loading has finished, so no request runs on a half-loaded profile.
	sessions[player] = session
	player:SetAttribute("ProfileOnline", session.online)
	local today = MetaRules.dayOf(now)
	local _, offline = GardenProgress.login(session.profile, now, today)
	player:SetAttribute("OfflineCoins", offline)
	apply(player, "login", function(p)
		return (GardenProgress.login(p, now, today))
	end)
	if player.Parent == nil then
		-- Left while loading (GardenServer's leave found no session): write the login, release the lock.
		Profiles.finish(player, os.time())
		return
	end
	if not session.online then
		Remotes.notice(player, if busy then BUSY_TEXT else OFFLINE_TEXT)
	end
	-- Decision 0008 estimates at most about 12 KB for a full record; this logs the real size.
	print(`[Profiles] {player.UserId} loaded ({#HttpService:JSONEncode(session.profile)} bytes encoded)`)
end

-- Request actions (decision 0008). Each decides on the profile it is given and returns
-- (next, accepted, coins paid or nil); the same function re-runs on the stored record.
type Handler = (Profile, number, number, string?) -> (Profile, boolean, number?)

local function idOf(arg: string?): number?
	return if arg then tonumber(arg) else nil
end

local ACTIONS: { [string]: Handler } = {
	buyEgg = function(p, now, _, arg)
		if arg == nil then
			return p, false
		end
		return GardenRules.buyEgg(p, arg, now)
	end,
	plantPrize = function(p, now, _, arg)
		if arg == nil then
			return p, false
		end
		return GardenRules.plantPrize(p, arg, now)
	end,
	buyBed = function(p)
		return GardenRules.buyBed(p)
	end,
	buyPenSlot = function(p)
		return GardenRules.buyPenSlot(p)
	end,
	place = function(p, _, _, arg)
		local id = idOf(arg)
		if id == nil then
			return p, false
		end
		return GardenRules.place(p, id)
	end,
	store = function(p, _, _, arg)
		local id = idOf(arg)
		if id == nil then
			return p, false
		end
		return GardenRules.store(p, id)
	end,
	release = function(p, _, today, arg)
		local id = idOf(arg)
		if id == nil then
			return p, false
		end
		return GardenProgress.release(p, id, today)
	end,
	favourite = function(p, _, _, arg)
		local id = idOf(arg)
		if id == nil then
			return p, false
		end
		return GardenRules.favourite(p, id)
	end,
	setGate = function(p, _, _, arg)
		if arg == nil then
			return p, false
		end
		return GardenProgress.setGate(p, arg)
	end,
	claimDaily = function(p, _, today)
		return GardenProgress.claimDaily(p, today)
	end,
	claimWeekly = function(p, _, today)
		return GardenProgress.claimWeekly(p, today)
	end,
	claimQuest = function(p, _, today, arg)
		if arg == nil then
			return p, false
		end
		return GardenProgress.claimQuest(p, today, arg)
	end,
	buyCosmetic = function(p, _, _, arg)
		if arg == nil then
			return p, false
		end
		return GardenProgress.buyCosmetic(p, arg)
	end,
	equipCosmetic = function(p, _, _, arg)
		if arg == nil then
			return p, false
		end
		return GardenProgress.equipCosmetic(p, arg)
	end,
	adminGrant = function(p, _, _, arg)
		local s, m, z = string.match(arg or "", "^(%a+):(%a+):(%a+)$")
		if s == nil or m == nil or z == nil then
			return p, false
		end
		return GardenRules.grant(p, s, m, z)
	end,
}

local rewardCount = 0

-- Runs a profile action after GardenServer's common and world checks. The pure rule decides on the
-- in-memory profile first; only an accepted change is applied and queued.
function Profiles.request(player: Player, action: string, arg: string?): boolean
	local session = sessions[player]
	local handler = ACTIONS[action]
	if session == nil or session.closing or handler == nil then
		return false
	end
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local _, ok, paid = handler(session.profile, now, today, arg)
	if not ok then
		return false
	end
	if paid and paid > 0 then
		-- The #n suffix makes two equal rewards in a row still change the attribute (the client strips it).
		rewardCount += 1
		player:SetAttribute("LastReward", `+{GardenRules.short(paid)} coins#{rewardCount}`)
	end
	apply(player, action, function(p)
		return (handler(p, now, today, arg))
	end)
	return true
end

-- 1 Hz: publish dirty sessions, flush due queues, write changed incomes to the board.
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
		local live = State.live[player]
		local since = now - session.lastWrite
		if not session.writing and ((#session.queue > 0 and since >= COALESCE) or since >= AUTOSAVE) then
			local unbanked = if live then GardenRules.unbanked(live.pads) else 0
			task.spawn(flush, player, session, now, unbanked)
		end
		if live and okBoard then
			local income = math.floor(GardenRules.income(session.profile))
			if income ~= live.boardIncome and now - live.boardAt >= BOARD_EVERY then
				live.boardIncome = income
				live.boardAt = now
				local key = keyFor(player)
				task.spawn(function()
					pcall(function()
						(board :: OrderedDataStore):SetAsync(key, income)
					end)
				end)
			end
		end
	end
end

-- Leave (GDD L): the caller has already banked every pad. Queues the leave op (unbanked = 0,
-- lastSeen = now), waits for any running flush, writes once more and drops the session.
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
			return GardenProgress.leave(p, now)
		end)
		session.closing = true
		while session.writing and os.clock() - started < INFLIGHT_WAIT do
			task.wait(0.1)
		end
		flush(player, session, now, 0, true, started + CLOSE_BUDGET)
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

-- Global top gardens board ------------------------------------------------------------------

-- Top 10 as { name, income }. Empty if the ordered store is unavailable.
function Profiles.topIncome(): { { name: string, income: number } }
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
		table.insert(rows, { name = name, income = entry.value })
	end
	return rows
end

return Profiles
