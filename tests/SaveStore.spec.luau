--!strict
-- Headless save tests: kit/SaveStore against tests/fakes/DataStore. Every guarantee listed at the
-- top of src/kit/SaveStore.luau has a test here.
local T = require("./framework")
local FakeDataStore = require("./fakes/DataStore")
local SaveLock = require("../src/kit/SaveLock")
local SaveStore = require("../src/kit/SaveStore")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = { coins: number, lastSeen: number }

local function sanitize(record: any, _now: number): Profile
	local coins = if type(record) == "table" and type(record.coins) == "number" then record.coins else 0
	local seen = if type(record) == "table" and type(record.lastSeen) == "number" then record.lastSeen else 0
	return { coins = math.max(0, math.floor(coins)), lastSeen = seen }
end

local function add(n: number)
	return function(p: Profile): Profile
		return { coins = p.coins + n, lastSeen = p.lastSeen }
	end
end

local ids = 0
local function make(store: any?)
	local clock = FakeDataStore.clock()
	local saves = SaveStore.new({
		store = store,
		defaults = function()
			return { coins = 0, lastSeen = 0 }
		end,
		sanitize = sanitize,
		snapshot = function(p: Profile, now: number): Profile
			return { coins = p.coins, lastSeen = now }
		end,
		wait = clock.wait,
		clock = clock.time,
		newId = function()
			ids += 1
			return `session-{ids}`
		end,
	})
	return saves, clock
end

describe("SaveLock", function()
	it("claims free, own and stale locks only", function()
		expect(SaveLock.canClaim(nil, "a", 0, 120)).toBe(true)
		expect(SaveLock.canClaim({ lock = { session = "a", at = 0 } }, "a", 10, 120)).toBe(true)
		expect(SaveLock.canClaim({ lock = { session = "b", at = 0 } }, "a", 10, 120)).toBe(false)
		expect(SaveLock.canClaim({ lock = { session = "b", at = 0 } }, "a", 120, 120)).toBe(true)
		-- A lock from the future (bad clock) also goes stale.
		expect(SaveLock.canClaim({ lock = { session = "b", at = 1000 } }, "a", 0, 120)).toBe(true)
		expect(SaveLock.canClaim({ lock = { session = 5, at = 0 } }, "a", 0, 120)).toBe(true)
	end)

	it("holds only its own lock; stamp sets or clears it without touching the input", function()
		local rec = { coins = 1 }
		local locked = SaveLock.stamp(rec, "a", 5)
		expect(SaveLock.holds(locked, "a")).toBe(true)
		expect(SaveLock.holds(locked, "b")).toBe(false)
		expect(rec.lock).toBeNil()
		expect(SaveLock.holds(SaveLock.stamp(locked, nil, 6), "a")).toBe(false)
	end)
end)

describe("SaveStore.load", function()
	it("loads, sanitises and locks an existing record", function()
		local store = FakeDataStore.new({ k = { coins = 12.7 } })
		local saves = make(store)
		local s = saves:load("k", 100)
		expect(s.status).toBe("online")
		expect(s.profile.coins).toBe(12)
		expect(SaveLock.holds(store:read("k"), s.id)).toBe(true)
	end)

	it("a failed load never writes and runs offline on defaults", function()
		local store = FakeDataStore.new({ k = { coins = 500 } })
		store:failNext(3)
		local saves, clock = make(store)
		local s = saves:load("k", 0)
		expect(s.status).toBe("offline")
		expect(s.profile.coins).toBe(0)
		expect(store.writes).toBe(0)
		expect(clock.waited).toBe(6) -- 2 s then 4 s between the three tries
		saves:apply("k", add(1))
		saves:finish("k", 10)
		expect(store:read("k").coins).toBe(500)
		expect(store.writes).toBe(0)
	end)

	it("recovers when a retry succeeds", function()
		local store = FakeDataStore.new({ k = { coins = 7 } })
		store:failNext(1)
		local saves = make(store)
		expect(saves:load("k", 0).status).toBe("online")
		expect(saves:get("k").coins).toBe(7)
	end)

	it("a second server cannot claim a fresh lock and writes nothing", function()
		local store = FakeDataStore.new()
		local first = make(store)
		first:load("k", 0)
		first:apply("k", add(10))
		first:flush("k", 7)
		local writes = store.writes
		local second = make(store)
		local s = second:load("k", 20)
		expect(s.status).toBe("busy")
		expect(store.writes).toBe(writes)
		second:apply("k", add(1000))
		second:finish("k", 30)
		expect(store:read("k").coins).toBe(10)
	end)

	it("a stale lock (crashed server) is taken over", function()
		local store = FakeDataStore.new({ k = { coins = 3, lock = { session = "dead", at = 0 } } })
		local saves = make(store)
		local s = saves:load("k", 120)
		expect(s.status).toBe("online")
		expect(s.profile.coins).toBe(3)
	end)

	it("without a store every session is offline", function()
		local saves = make(nil)
		expect(saves:load("k", 0).status).toBe("offline")
		expect(saves:isOnline("k")).toBe(false)
	end)
end)

describe("SaveStore writes", function()
	it("applies changes in memory at once and coalesces writes", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		saves:load("k", 0)
		local base = store.writes
		saves:apply("k", add(1))
		saves:apply("k", add(2))
		expect(saves:get("k").coins).toBe(3)
		expect(saves:due("k", 6)).toBe(false)
		saves:step(6)
		expect(store.writes).toBe(base)
		saves:step(7)
		expect(store.writes).toBe(base + 1)
		expect(store:read("k").coins).toBe(3)
		expect(store:read("k").lastSeen).toBe(7)
	end)

	it("autosaves with nothing queued", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		saves:load("k", 0)
		expect(saves:due("k", 59)).toBe(false)
		expect(saves:due("k", 60)).toBe(true)
	end)

	it("re-applies queued changes on the stored record, so a stale copy never overwrites", function()
		local store = FakeDataStore.new({ k = { coins = 0 } })
		local saves = make(store)
		local s = saves:load("k", 0)
		saves:apply("k", add(5))
		-- Another writer (a gift, an admin fix) changes the stored record under the same lock.
		local rec = store:read("k")
		rec.coins = 100
		store:write("k", rec)
		saves:flush("k", 7)
		expect(store:read("k").coins).toBe(105)
		expect(saves:get("k").coins).toBe(105)
		expect(SaveLock.holds(store:read("k"), s.id)).toBe(true)
	end)

	it("keeps changes made while a write is in flight", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		saves:load("k", 0)
		saves:apply("k", add(1))
		store.during = function()
			saves:apply("k", add(10))
		end
		saves:flush("k", 7)
		expect(store:read("k").coins).toBe(1)
		expect(saves:get("k").coins).toBe(11)
		saves:flush("k", 14)
		expect(store:read("k").coins).toBe(11)
	end)

	it("a failed flush puts its changes back at the front of the queue", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		saves:load("k", 0)
		saves:apply("k", add(1))
		store:failNext(3)
		expect(saves:flush("k", 7)).toBe(false)
		saves:apply("k", add(2))
		expect(#(saves:session("k") :: any).queue).toBe(2)
		expect(saves:flush("k", 20)).toBe(true)
		expect(store:read("k").coins).toBe(3)
	end)

	it("a write that finds the lock taken writes nothing and goes offline", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		local lost = {}
		saves.onLost = function(key)
			table.insert(lost, key)
		end
		saves:load("k", 0)
		saves:apply("k", add(1))
		local rec = store:read("k")
		rec.lock = { session = "other", at = 5 }
		rec.coins = 50
		store:write("k", rec)
		expect(saves:flush("k", 7)).toBe(false)
		expect(saves:isOnline("k")).toBe(false)
		expect(lost[1]).toBe("k")
		saves:apply("k", add(1))
		saves:finish("k", 9)
		expect(store:read("k").coins).toBe(50)
		expect(store:read("k").lock.session).toBe("other")
	end)

	it("a change that throws or returns nil is ignored", function()
		local saves = make(FakeDataStore.new())
		saves:load("k", 0)
		expect(saves:apply("k", function()
			error("bug")
		end)).toBe(false)
		expect(saves:apply("k", function()
			return nil :: any
		end)).toBe(false)
		expect(saves:get("k").coins).toBe(0)
		expect(#(saves:session("k") :: any).queue).toBe(0)
	end)
end)

describe("SaveStore.finish", function()
	it("writes once more, releases the lock and drops the session", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		saves:load("k", 0)
		saves:apply("k", add(4))
		saves:finish("k", 3)
		local rec = store:read("k")
		expect(rec.coins).toBe(4)
		expect(rec.lock).toBeNil()
		expect(saves:get("k")).toBeNil()
		-- The next server claims it immediately.
		expect(make(store):load("k", 4).status).toBe("online")
	end)

	it("is safe to call twice and refuses changes once closing", function()
		local store = FakeDataStore.new()
		local saves = make(store)
		saves:load("k", 0)
		saves:finish("k", 1)
		saves:finish("k", 2)
		expect(saves:apply("k", add(1))).toBe(false)
	end)
end)
