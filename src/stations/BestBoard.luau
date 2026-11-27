--!strict
-- The top-100 best-wave board at the hub (decision 0129). Each player's best wave is written to an ordered data
-- store when it rises (at most once a WRITE_EVERY seconds a player, and again on leaving); every READ_EVERY seconds
-- the server reads the top 100 and writes them on the hub's board (World.setBest). Display only: a failed read or
-- write is logged and tried again later; nothing in a save depends on it.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Saves = require(ReplicatedStorage:WaitForChild("KitRoblox"):WaitForChild("Saves"))
local World = require(script.Parent:WaitForChild("World"))

local BestBoard = {}

BestBoard.TOP, BestBoard.WRITE_EVERY, BestBoard.READ_EVERY = 100, 60, 120

local store: OrderedDataStore? = nil
do
	local ok, got = pcall(function()
		return DataStoreService:GetOrderedDataStore("StationsBestWave" .. Saves.suffix())
	end)
	if ok then
		store = got
	end
end

local sent: { [Player]: number } = {} -- the best already written
local want: { [Player]: number } = {} -- the best to write
local lastWrite: { [Player]: number } = {}

local function write(player: Player)
	local s, best = store, want[player]
	if s == nil or best == nil or best <= (sent[player] or 0) then
		return
	end
	lastWrite[player] = os.clock()
	local ok, err = pcall(function()
		s:SetAsync(tostring(player.UserId), best)
	end)
	if ok then
		sent[player] = best
	else
		warn(`[BestBoard] could not write {player.UserId}: {err}`)
	end
end

-- The player's best wave now (from the save); written when it has risen, not more often than WRITE_EVERY.
function BestBoard.report(player: Player, best: number)
	if best <= 0 or best <= (want[player] or 0) then
		return
	end
	want[player] = best
	local wait = BestBoard.WRITE_EVERY - (os.clock() - (lastWrite[player] or -math.huge))
	if wait <= 0 then
		task.spawn(write, player)
	else
		task.delay(wait, write, player)
	end
end

function BestBoard.leave(player: Player)
	write(player)
	sent[player], want[player], lastWrite[player] = nil, nil, nil
end

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local ok, got = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local name = if ok and type(got) == "string" then got else "?"
	names[userId] = name
	return name
end

-- Read the top TOP and write them on the board.
function BestBoard.refresh()
	local s = store
	if s == nil then
		return
	end
	local ok, page = pcall(function()
		return s:GetSortedAsync(false, BestBoard.TOP):GetCurrentPage()
	end)
	if not ok then
		warn(`[BestBoard] could not read: {page}`)
		return
	end
	local rows = {}
	for i, entry in page :: any do
		local id = tonumber(entry.key)
		table.insert(rows, `{i}. {if id then nameOf(id) else "?"}  {entry.value}`)
	end
	World.setBest(rows)
end

function BestBoard.start()
	World.setBest({})
	task.spawn(function()
		while true do
			BestBoard.refresh()
			task.wait(BestBoard.READ_EVERY)
		end
	end)
end

return BestBoard
