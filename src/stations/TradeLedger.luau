--!strict
-- The trade ledger (decision 0099). Before a trade changes either save, both sides are written here: one
-- key a player ("player_<UserId>"), the newest KEEP sides first. Each side is a StationTrade.Side and when
-- it was made. A trade a crash or a failed save cut short is finished at that player's next login
-- (`StationsServer`'s heal): every side younger than StationTrade.HEAL_SECONDS whose id the save does not
-- have and that is not cancelled. A side whose trade stopped after it was written is marked cancelled.
-- In Studio without published DataStores there is no store: every call answers false (nothing persists
-- there either, so nothing can be duplicated).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Saves = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Saves"))
local StationTrade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StationTrade"))

local TradeLedger = {}

local TRIES = 3

local store: DataStore? = nil
do
	local ok, got = pcall(function()
		return DataStoreService:GetDataStore("StationsTrades" .. Saves.suffix())
	end)
	if ok then
		store = got
	end
end

local function update(userId: number, change: (list: { any }) -> { any }): boolean
	local s = store
	if s == nil then
		return false
	end
	for try = 1, TRIES do
		local ok = pcall(function()
			s:UpdateAsync(`player_{userId}`, function(old)
				return change(if type(old) == "table" then old else {})
			end)
		end)
		if ok then
			return true
		end
		task.wait(try)
	end
	warn(`[TradeLedger] could not write for {userId}`)
	return false
end

-- Whether there is a store to write to.
function TradeLedger.available(): boolean
	return store ~= nil
end

-- Write one side of a trade for `userId`; false when it could not be written.
function TradeLedger.write(userId: number, side: any, now: number): boolean
	return update(userId, function(list)
		return StationTrade.ledgerAdd(list, side, now)
	end)
end

-- Mark trade `id` cancelled in `userId`'s key, so the heal never applies it.
function TradeLedger.cancel(userId: number, id: string): boolean
	return update(userId, function(list)
		return StationTrade.ledgerCancel(list, id)
	end)
end

-- `userId`'s sides, newest first, or nil when the store could not be read.
function TradeLedger.read(userId: number): { any }?
	local s = store
	if s == nil then
		return nil
	end
	for try = 1, TRIES do
		local ok, got = pcall(function()
			return s:GetAsync(`player_{userId}`)
		end)
		if ok then
			return if type(got) == "table" then got else {}
		end
		task.wait(try)
	end
	return nil
end

return TradeLedger
