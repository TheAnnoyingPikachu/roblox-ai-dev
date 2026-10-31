--!strict
-- Kit: the session lock stored on a saved record, generalised from GardenProgress (decision 0008
-- amendment 2026-10-26). Pure.
--
-- A load claims `record.lock = { session, at }`; every later write refreshes `at` and only runs
-- while this session still holds the lock; the final write clears it. A lock whose `at` is more than
-- `stale` seconds from now (either way, so a bad clock cannot pin a record forever) can be taken.

local SaveLock = {}

export type Lock = { session: string, at: number }

function SaveLock.of(record: any): Lock?
	local lock = if type(record) == "table" then record.lock else nil
	if
		type(lock) == "table"
		and type(lock.session) == "string"
		and type(lock.at) == "number"
		and lock.at == lock.at
	then
		return lock
	end
	return nil
end

function SaveLock.canClaim(record: any, session: string, now: number, stale: number): boolean
	local lock = SaveLock.of(record)
	return lock == nil or lock.session == session or math.abs(now - lock.at) >= stale
end

function SaveLock.holds(record: any, session: string): boolean
	local lock = SaveLock.of(record)
	return lock ~= nil and lock.session == session
end

-- A shallow copy of `record` carrying this session's lock at `now`, or no lock when `session` is nil.
function SaveLock.stamp(record: { [any]: any }, session: string?, now: number): { [any]: any }
	local out = table.clone(record)
	out.lock = if session then { session = session, at = now } else nil
	return out
end

return SaveLock
