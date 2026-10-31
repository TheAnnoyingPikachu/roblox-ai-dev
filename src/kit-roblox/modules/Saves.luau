--!strict
-- Kit (Roblox side): binds kit/SaveStore to DataStoreService, Players and BindToClose. Server only.
-- All save decisions (locking, coalescing, retries, re-apply) live in the pure SaveStore and are
-- tested headless in tests/SaveStore.spec.luau; this file only supplies the Roblox services.
--
--   local saves = Saves.start({
--       name = "SpireProfile",               -- store "<name><suffix>": _studio, _staging or ""
--       defaults = SpireProgress.defaults,
--       sanitize = SpireProgress.sanitize,
--       snapshot = SpireProgress.snapshot,
--       onChanged = function(player, profile) ... end,  -- publish attributes for the UI
--   })
--   Players.PlayerAdded:Connect(function(player) saves.load(player) end)
--   saves.apply(player, function(p) return SpireRules.buyFloor(p, dept) end)
--
-- PRODUCTION_UNIVERSE_ID stays nil until SHANNON approves a production release (CLAUDE.md rule 7):
-- until then every live server writes to the _staging stores.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SaveStore = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("SaveStore"))

local Saves = {}

export type Options = {
	name: string,
	productionUniverseId: number?,
	defaults: (now: number) -> any,
	sanitize: (record: any, now: number) -> any,
	snapshot: ((p: any, now: number) -> any)?,
	onChanged: ((player: Player, profile: any) -> ())?,
	onStatus: ((player: Player, status: string) -> ())?, -- "online" | "busy" | "offline" | "lost"
	coalesce: number?,
	autosave: number?,
	lockStale: number?,
}

local CLOSE_BUDGET = 25 -- BindToClose has 30 s

function Saves.suffix(productionUniverseId: number?): string
	if RunService:IsStudio() then
		return "_studio"
	end
	if productionUniverseId ~= nil and game.GameId == productionUniverseId then
		return ""
	end
	return "_staging"
end

function Saves.start(options: Options)
	local okStore, store = pcall(function()
		return DataStoreService:GetDataStore(options.name .. Saves.suffix(options.productionUniverseId))
	end)
	if not okStore then
		warn(`[Saves] {options.name}: DataStores unavailable, every session is offline: {store}`)
	end

	local saves = SaveStore.new({
		store = if okStore then store :: any else nil,
		defaults = options.defaults,
		sanitize = options.sanitize,
		snapshot = options.snapshot,
		wait = function(seconds)
			task.wait(seconds)
		end,
		clock = os.clock,
		newId = function()
			return HttpService:GenerateGUID(false)
		end,
		coalesce = options.coalesce,
		autosave = options.autosave,
		lockStale = options.lockStale,
		log = function(message)
			warn(message)
		end,
	})

	local byKey: { [string]: Player } = {}
	local function keyFor(player: Player): string
		return `player_{player.UserId}`
	end
	local function changed(player: Player)
		local profile = saves:get(keyFor(player))
		if profile ~= nil and options.onChanged then
			options.onChanged(player, profile)
		end
	end

	saves.onLost = function(key)
		local player = byKey[key]
		if player and options.onStatus then
			options.onStatus(player, "lost")
		end
	end

	local api = {}
	api.store = saves

	-- Blocks until loaded. Requests must wait for this (kit/Router `ready` = api.isLoaded).
	function api.load(player: Player)
		local key = keyFor(player)
		byKey[key] = player
		local session = saves:load(key, os.time())
		player:SetAttribute("ProfileOnline", session.status == "online")
		if options.onStatus then
			options.onStatus(player, session.status)
		end
		if player.Parent == nil then
			api.finish(player)
			return
		end
		changed(player)
		print(`[Saves] {player.UserId} {session.status} ({#HttpService:JSONEncode(session.profile)} bytes encoded)`)
	end

	function api.isLoaded(player: Player): boolean
		return saves:session(keyFor(player)) ~= nil
	end

	function api.isOnline(player: Player): boolean
		return saves:isOnline(keyFor(player))
	end

	function api.get(player: Player): any?
		return saves:get(keyFor(player))
	end

	-- `change` must be pure and capture its own inputs (it re-runs on the stored record).
	function api.apply(player: Player, change: (any) -> any): boolean
		local ok = saves:apply(keyFor(player), change)
		if ok then
			changed(player)
		end
		return ok
	end

	function api.finish(player: Player)
		local key = keyFor(player)
		saves:finish(key, os.time(), CLOSE_BUDGET)
		byKey[key] = nil
	end

	Players.PlayerRemoving:Connect(api.finish)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				api.finish(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < CLOSE_BUDGET + 2 do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			saves:step(os.time(), function(flush, self, key, now)
				task.spawn(function()
					-- A stored write adopts the record re-read from the store; republish it.
					if flush(self, key, now) and byKey[key] then
						changed(byKey[key])
					end
				end)
			end)
		end
	end)

	return api
end

return Saves
