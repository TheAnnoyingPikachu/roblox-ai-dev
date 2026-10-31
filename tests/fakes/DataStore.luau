--!strict
-- In-memory stand-in for a Roblox DataStore, for headless save tests. Records are deep-copied on
-- the way in and out, like the real JSON round trip, so a test cannot pass by sharing tables.
--
--   local store = FakeDataStore.new()
--   store:failNext(2)            -- the next two calls throw, like a DataStore outage
--   store.during = function() end -- runs inside the next UpdateAsync, before the write (races)

local FakeDataStore = {}
FakeDataStore.__index = FakeDataStore

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[deepCopy(k)] = deepCopy(v)
	end
	return out
end

export type Fake = {
	data: { [string]: any },
	writes: number,
	calls: number,
	failing: number,
	during: (() -> ())?,
}

function FakeDataStore.new(initial: { [string]: any }?)
	local self = { data = deepCopy(initial or {}), writes = 0, calls = 0, failing = 0, during = nil }
	return setmetatable(self, FakeDataStore)
end

function FakeDataStore.failNext(self: any, n: number)
	self.failing = n
end

function FakeDataStore.read(self: any, key: string): any
	return deepCopy(self.data[key])
end

function FakeDataStore.write(self: any, key: string, value: any)
	self.data[key] = deepCopy(value)
end

function FakeDataStore.UpdateAsync(self: any, key: string, transform: (any) -> any): any
	self.calls += 1
	if self.failing > 0 then
		self.failing -= 1
		error("FakeDataStore: simulated outage", 2)
	end
	local result = transform(deepCopy(self.data[key]))
	local during = self.during
	if during then
		self.during = nil
		during()
	end
	if result == nil then
		return nil
	end
	self.data[key] = deepCopy(result)
	self.writes += 1
	return deepCopy(result)
end

-- A controllable clock: `wait` advances it, so retry backoff runs instantly in tests.
function FakeDataStore.clock()
	local c = { now = 0, waited = 0 }
	function c.time(): number
		return c.now
	end
	function c.wait(seconds: number)
		c.now += seconds
		c.waited += seconds
	end
	return c
end

return FakeDataStore
