--!strict
-- Kit: session-locked, coalesced player saves. This is the save pattern from Egg Garden's
-- Profiles.luau (decision 0008, after the GARDEN-006 QA fixes) with the Roblox services injected,
-- so the whole thing runs headless under Lune with tests/fakes/DataStore.luau.
-- src/kit-roblox/Saves.luau binds it to DataStoreService, Players and BindToClose.
--
-- Guarantees (each one has a test in tests/SaveStore.spec.luau):
--   * A failed or refused load never writes. The session runs on defaults, offline, and says why.
--   * The load claims a session lock; a second server cannot claim a fresh lock (status "busy").
--   * Every change runs on the in-memory profile at once and is queued. A flush re-reads the stored
--     record, sanitises it, re-runs the queued changes in order and stores the result in one
--     UpdateAsync, so a stale copy can never overwrite newer progress.
--   * At most one write per `coalesce` seconds while changes are queued, plus an `autosave` write.
--   * A failed flush puts its changes back at the front of the queue.
--   * A write that finds the lock gone or taken writes nothing and the session goes offline.
--   * `finish` writes once more and releases the lock.
--
-- Changes must be pure functions of the profile that capture their own inputs (now, ids): the same
-- function runs on the in-memory copy and again on the stored copy inside UpdateAsync.

local SaveLock = require("./SaveLock")

local SaveStore = {}
SaveStore.__index = SaveStore

export type Change<P> = (P) -> P
export type Store = { UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any }
export type Status = "online" | "busy" | "offline"

export type Options<P> = {
	store: Store?, -- nil: DataStores unavailable, every session is offline
	defaults: (now: number) -> P,
	sanitize: (record: any, now: number) -> P,
	snapshot: ((p: P, now: number) -> P)?, -- runs last on every write (lastSeen and so on)
	wait: (seconds: number) -> (),
	clock: () -> number, -- monotonic seconds, for budgets
	newId: () -> string, -- one id per load (lock owner)
	attempts: number?, -- default 3, waits 2 s then 4 s between tries
	coalesce: number?, -- default 7
	autosave: number?, -- default 60
	lockStale: number?, -- default 120 (2 x autosave)
	inflightWait: number?, -- default 10: longest wait in finish for a running write
	log: ((message: string) -> ())?,
}

export type Session<P> = {
	id: string,
	key: string,
	profile: P,
	status: Status,
	queue: { Change<P> },
	writing: boolean,
	lastWrite: number,
	closing: boolean,
}

type Self<P> = {
	o: Options<P>,
	sessions: { [string]: Session<P> },
	attempts: number,
	coalesce: number,
	autosave: number,
	lockStale: number,
	inflightWait: number,
	onLost: ((key: string) -> ())?,
}

function SaveStore.new<P>(options: Options<P>)
	local self: Self<P> = {
		o = options,
		sessions = {},
		attempts = options.attempts or 3,
		coalesce = options.coalesce or 7,
		autosave = options.autosave or 60,
		lockStale = options.lockStale or 120,
		inflightWait = options.inflightWait or 10,
		onLost = nil,
	}
	return setmetatable(self, SaveStore)
end

local function log(self: any, message: string)
	if self.o.log then
		self.o.log(`[SaveStore] {message}`)
	end
end

-- Runs `operation` up to `attempts` times with 2^n second waits; no wait that would end after
-- `deadline` (clock time).
local function withRetries(self: any, label: string, operation: () -> any, deadline: number?): (boolean, any)
	local lastError: any = nil
	for attempt = 1, self.attempts do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		log(self, `{label} attempt {attempt} failed: {tostring(result)}`)
		if attempt == self.attempts or (deadline and self.o.clock() + 2 ^ attempt > deadline) then
			break
		end
		self.o.wait(2 ^ attempt)
	end
	return false, lastError
end

-- Loads (and locks) `key`. Blocks until done. Returns the session; check `session.status`.
function SaveStore.load(self: any, key: string, now: number): Session<any>
	local o = self.o
	local session: Session<any> = {
		id = o.newId(),
		key = key,
		profile = o.defaults(now),
		status = "offline",
		queue = {},
		writing = false,
		lastWrite = now,
		closing = false,
	}
	if o.store then
		local busy = false
		local ok, record = withRetries(self, `load {key}`, function()
			local stored = o.store:UpdateAsync(key, function(old: any)
				busy = not SaveLock.canClaim(old, session.id, now, self.lockStale)
				if busy then
					return nil
				end
				return SaveLock.stamp(o.sanitize(old, now) :: any, session.id, now)
			end)
			if busy then
				error("record is locked by another session")
			end
			return stored
		end)
		if ok then
			session.status = "online"
			session.profile = o.sanitize(record, now)
		elseif busy then
			session.status = "busy"
		end
	end
	self.sessions[key] = session
	return session
end

function SaveStore.get(self: any, key: string): any?
	local session = self.sessions[key]
	return session and session.profile
end

function SaveStore.session(self: any, key: string): Session<any>?
	return self.sessions[key]
end

function SaveStore.isOnline(self: any, key: string): boolean
	local session = self.sessions[key]
	return session ~= nil and session.status == "online"
end

-- Applies `change` now and queues it for the store. Returns false (and changes nothing) when there
-- is no session, the session is closing, or `change` throws.
function SaveStore.apply(self: any, key: string, change: Change<any>): boolean
	local session = self.sessions[key]
	if session == nil or session.closing then
		return false
	end
	local ok, result = pcall(change, session.profile)
	if not ok or result == nil then
		log(self, `change on {key} failed: {tostring(result)}`)
		return false
	end
	session.profile = result
	if session.status == "online" then
		table.insert(session.queue, change)
	end
	return true
end

function SaveStore.due(self: any, key: string, now: number): boolean
	local session = self.sessions[key]
	if session == nil or session.status ~= "online" or session.writing or session.closing then
		return false
	end
	local since = now - session.lastWrite
	return (#session.queue > 0 and since >= self.coalesce) or since >= self.autosave
end

local function goOffline(self: any, session: Session<any>)
	log(self, `{session.key} lost the session lock; saving is off for this session`)
	session.status = "offline"
	session.queue = {}
	if self.onLost and not session.closing then
		self.onLost(session.key)
	end
end

-- One UpdateAsync as described at the top. Returns true when the record was stored.
function SaveStore.flush(self: any, key: string, now: number, final: boolean?, deadline: number?): boolean
	local o = self.o
	local session = self.sessions[key]
	if session == nil or session.status ~= "online" or o.store == nil then
		return false
	end
	session.writing = true
	session.lastWrite = now
	local ops = session.queue
	session.queue = {}
	local lost = false
	local ok, stored = withRetries(self, `flush {key}`, function()
		return o.store:UpdateAsync(key, function(old: any)
			lost = not SaveLock.holds(old, session.id)
			if lost then
				return nil
			end
			local p = o.sanitize(old, now)
			for _, op in ops do
				p = op(p)
			end
			if o.snapshot then
				p = o.snapshot(p, now)
			end
			return SaveLock.stamp(p :: any, if final then nil else session.id, now)
		end)
	end, deadline)
	session.writing = false
	if lost then
		goOffline(self, session)
		return false
	elseif ok and stored ~= nil then
		local p = o.sanitize(stored, now)
		for _, op in session.queue do
			p = op(p)
		end
		session.profile = p
		return true
	end
	for i, op in ops do
		table.insert(session.queue, i, op)
	end
	return false
end

-- Flushes every due session. `spawn` runs each flush (task.spawn on Roblox; default: inline).
function SaveStore.step(self: any, now: number, spawn: ((f: any, ...any) -> ())?)
	for key in self.sessions do
		if SaveStore.due(self, key, now) then
			if spawn then
				spawn(SaveStore.flush, self, key, now)
			else
				SaveStore.flush(self, key, now)
			end
		end
	end
end

-- Final write (releases the lock) and drops the session. Safe to call twice (leave and BindToClose).
function SaveStore.finish(self: any, key: string, now: number, budget: number?)
	local o = self.o
	local session = self.sessions[key]
	if session == nil then
		return
	end
	local started = o.clock()
	local limit = budget or 25
	if session.closing then
		while self.sessions[key] == session and o.clock() - started < limit do
			o.wait(0.1)
		end
		return
	end
	session.closing = true
	if session.status == "online" then
		while session.writing and o.clock() - started < self.inflightWait do
			o.wait(0.1)
		end
		SaveStore.flush(self, key, now, true, started + limit)
	end
	if self.sessions[key] == session then
		self.sessions[key] = nil
	end
end

return SaveStore
