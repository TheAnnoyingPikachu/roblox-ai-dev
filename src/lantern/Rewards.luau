--!strict
-- Lantern Express rewards (docs/architecture/lantern.md 4.6, 4.7; GDD J): every payout is one
-- `saves.apply` on one player's own save, with a change that captures its inputs (items, n, today)
-- and calls a pure LanternProgress function. Loads pay the moment they reach the train; Depots,
-- Dawn, the Lampeater, leftover Parts and stop XP pay every member aboard; the run end writes bests
-- and the weekly boards. Nothing here ever takes anything away.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitRoblox = ReplicatedStorage:WaitForChild("KitRoblox")
local LanternConfig = require(Shared:WaitForChild("LanternConfig"))
local LanternProgress = require(Shared:WaitForChild("LanternProgress"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local TrainRules = require(Shared:WaitForChild("TrainRules"))
local Saves = require(KitRoblox:WaitForChild("Saves"))
local World = require(script.Parent:WaitForChild("World"))

local Rewards = {}

type Profile = LanternProgress.Profile
type Paid = LanternProgress.Paid
type Remotes = { fx: (Player, string, any) -> (), fxAll: (string, any) -> () }

local RARE = { rare = true, epic = true, legendary = true }
local BOARDS = { critters = "Critters", dist = "Dist" }

local saves: any = nil
local remotes: Remotes = nil :: any
local earned: { [number]: { tickets: number, xp: number } } = {} -- this run, for the end card
local names: { [number]: string } = {}
local boardLists: { [string]: { { name: string, value: number } } } = { critters = {}, dist = {} }
local boardValue: StringValue

function Rewards.start(s: any, r: Remotes)
	saves, remotes = s, r
	boardValue = Instance.new("StringValue")
	boardValue.Name = "LanternBoards"
	boardValue.Value = HttpService:JSONEncode(boardLists) -- { critters = {}, dist = {} } until a read lands
	boardValue.Parent = ReplicatedStorage
end

local function today(): number
	return MetaRules.dayOf(os.time())
end

-- Applies `fn` (pure: profile -> (profile, paid)) to `player`'s save; tells them what it paid.
-- `fn` runs once on the live profile for the toast and again inside the save's queue.
local function pay(player: Player, fn: (Profile) -> (Profile, Paid)): Paid?
	local profile = saves.get(player)
	if profile == nil then
		return nil
	end
	local _, paid = fn(profile)
	if not saves.apply(player, function(p)
		return (fn(p))
	end) then
		return nil
	end
	local tally = earned[player.UserId] or { tickets = 0, xp = 0 }
	tally.tickets += paid.tickets
	tally.xp += paid.xp
	earned[player.UserId] = tally
	if paid.text ~= "" then
		player:SetAttribute("LastReward", paid.text)
		remotes.fx(player, "payout", { tickets = paid.tickets, xp = paid.xp, text = paid.text })
	end
	return paid
end

-- One "load" event: every active member's share (G4: idle members earn no load shares), the
-- carrier's XP, rescues for everyone, then the display Fx.
function Rewards.load(run: TrainRules.Run, e: TrainRules.Event, now: number)
	local items: { LanternProgress.Loaded } = {}
	local counts: { [string]: number } = {}
	for _, item in e.items or {} do
		table.insert(items, { kind = item.kind, species = item.species, rarity = item.rarity })
		counts[item.kind] = (counts[item.kind] or 0) + 1
	end
	local carrier, n, day = e.userId :: number, e.n or 1, today()
	for _, userId in run.order do
		local m = run.crew[userId]
		local player = Players:GetPlayerByUserId(userId)
		if player and now - m.active <= LanternConfig.CREW.active then
			local mine = userId == carrier
			local paid = pay(player, function(p)
				return LanternProgress.load(p, items, mine, n, day)
			end)
			for _, species in if paid then paid.new else {} do
				remotes.fx(player, "new", { species = species })
			end
		end
	end
	for kind, count in counts do
		remotes.fxAll("load", { by = carrier, kind = kind, count = count })
	end
	local who = Players:GetPlayerByUserId(carrier)
	for _, item in items do
		if item.kind == "critter" and item.species then
			remotes.fxAll("rescue", { by = carrier, species = item.species, rarity = item.rarity })
			if RARE[item.rarity or ""] and who then
				remotes.fxAll("announce", { name = who.DisplayName, species = item.species, rarity = item.rarity })
			end
		end
	end
end

-- "depot", "dawn", "fed" or "stop" for one player (amount: leftover Parts share for "parts").
function Rewards.award(player: Player, kind: "depot" | "dawn" | "fed" | "parts" | "stop", amount: number?)
	local day, value = today(), amount or 0
	pay(player, function(p)
		return LanternProgress.award(p, kind, value, day)
	end)
end

-- The same for every member aboard.
function Rewards.awardAll(run: TrainRules.Run, kind: "depot" | "dawn" | "fed")
	for _, userId in run.order do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			Rewards.award(player, kind)
		end
	end
end

-- Puffs, stokes, mends and catches (no toast; their XP still counts on the end card).
function Rewards.count(player: Player, key: "puffs" | "stokes" | "mends" | "caught", by: number)
	local day = today()
	local before = saves.get(player)
	if before and saves.apply(player, function(p)
		return LanternProgress.count(p, key, by, day)
	end) then
		local tally = earned[player.UserId] or { tickets = 0, xp = 0 }
		tally.xp += saves.get(player).xp - before.xp
		earned[player.UserId] = tally
	end
end

local function boardStore(kind: string, week: number): OrderedDataStore
	return DataStoreService:GetOrderedDataStore(`LanternWeek{BOARDS[kind]}{week}{Saves.suffix(nil)}`)
end

-- Keeps the larger value; a failure is logged and the player's weekBest still holds it.
local function submit(kind: string, week: number, userId: number, value: number)
	task.spawn(function()
		local ok, err = pcall(function()
			boardStore(kind, week):UpdateAsync(`player_{userId}`, function(old: any)
				return math.max(if type(old) == "number" then old else 0, math.floor(value))
			end)
		end)
		if not ok then
			warn(`[Rewards] weekly {kind} board write failed: {tostring(err)}`)
		end
	end)
end

-- The "end" event: leftover Parts, bests (and the weekly boards for a weekly run), then each
-- member's own end card.
function Rewards.runEnd(run: TrainRules.Run, e: TrainRules.Event)
	local payload = e.payload or {}
	local day = today()
	local week = if run.weekly then MetaRules.weekOf(day) else nil
	local critters, dist, dawn = payload.critters or 0, payload.dist or 0, e.reason == "dawn"
	for _, userId in run.order do
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and saves.get(player)
		if player and profile then
			if (payload.parts or 0) > 0 then
				Rewards.award(player, "parts", payload.parts)
			end
			local _, improved = LanternProgress.runEnd(saves.get(player), critters, dist, week, dawn)
			saves.apply(player, function(p)
				return (LanternProgress.runEnd(p, critters, dist, week, dawn))
			end)
			if week and improved.critters then
				submit("critters", week, userId, critters)
			end
			if week and improved.dist then
				submit("dist", week, userId, if dawn then TrainRules.MAX_DIST else dist)
			end
			local tally = earned[userId] or { tickets = 0, xp = 0 }
			remotes.fx(player, "runEnd", {
				reason = e.reason,
				summary = { critters = critters, dist = dist, tickets = tally.tickets, xp = tally.xp },
			})
		end
	end
end

-- A new run: the end card tallies start again.
function Rewards.reset()
	earned = {}
end

local function displayNames(ids: { number })
	local missing = {}
	for _, id in ids do
		if names[id] == nil then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

-- Reads the top 10 of both weekly boards (yields; call from a spawned thread every 60 s). A failed
-- read keeps the last list.
function Rewards.refreshBoards()
	local week = MetaRules.weekOf(today())
	for kind in BOARDS do
		local ok, page = pcall(function()
			return boardStore(kind, week):GetSortedAsync(false, 10):GetCurrentPage()
		end)
		if ok then
			local ids = {}
			for _, entry in page do
				table.insert(ids, tonumber(string.match(entry.key, "%d+")) or 0)
			end
			displayNames(ids)
			local list = {}
			for i, entry in page do
				table.insert(list, { name = names[ids[i]] or "Conductor", value = entry.value })
			end
			boardLists[kind] = list
		end
	end
	boardValue.Value = HttpService:JSONEncode(boardLists)
	World.boards(boardLists)
end

return Rewards
