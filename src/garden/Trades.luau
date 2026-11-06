--!strict
-- Safe trading on the server (GDD V1, docs/architecture/garden.md 4.5). Owns the live trades, the
-- GardenTrades<suffix> ledger, and the commit, undo and heal sequences. TradeRules decides every
-- transition and every profile change; this module checks who is here, who is a friend, who stands
-- where, and writes in the one safe order: both ledger keys, re-check, two applies with no yield.
--
-- Test seam: every outside call goes through `Trades.deps`, which GardenServer fills with the real
-- Profiles, Remotes and player lookups. A Studio harness replaces them with in-memory fakes keyed by
-- mock player tables (only `UserId` and `DisplayName` are read from a player), so the full sequence,
-- ledger writes included, runs with two fake players in one server.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local GardenRules = require(Shared:WaitForChild("GardenRules"))
local MetaRules = require(Shared:WaitForChild("MetaRules"))
local TradeRules = require(Shared:WaitForChild("TradeRules"))
local State = require(script.Parent:WaitForChild("State"))

type Profile = GardenConfig.Profile
type Creature = GardenConfig.Creature
type Trade = TradeRules.Trade
type Ledger = TradeRules.Ledger
type Vec3 = GardenRules.Vec3

export type Deps = {
	get: (Player) -> Profile?,
	isOnline: (Player) -> boolean,
	apply: (Player, string, (Profile) -> Profile) -> (),
	withRetries: (string, () -> any, number?) -> (boolean, any),
	storeSuffix: () -> string,
	playerOf: (number) -> Player?,
	rootPos: (Player) -> Vec3?,
	isFriend: (Player, Player) -> boolean, -- the waiting form; the caller asks both directions
	send: (Player, string, { [string]: any }) -> (),
	notice: (Player, string) -> (),
	ledger: any?, -- harness only: an object with UpdateAsync and GetAsync in place of GardenTrades<suffix>
}

type Pair = { t: Trade, a: Player, b: Player }

local TRADE = GardenConfig.TRADE
local FRIENDS_TEXT = "You can only trade with your Roblox friends."
local ONLINE_TEXT = "Trading needs saving to be on for both of you."
local LIMIT_TEXT = `You have done your {TRADE.perDay} trades for today. More tomorrow!`
local UNDO_RETRY_TEXT = "Could not undo right now, try again"
local UNDO_RELEASED_TEXT = "That creature was released, so the trade cannot be undone"
local UNDO_BOTH_TEXT = "Undo needs both of you here with saving on."

local Trades = {}
Trades.deps = nil :: Deps?

local live: { [Player]: Pair } = {}
local closed = false
local store: DataStore? = nil

local function D(): Deps
	return Trades.deps :: Deps
end

local function ledgerStore(): DataStore?
	if D().ledger then
		return D().ledger
	end
	if store == nil then
		local ok, s = pcall(function()
			return DataStoreService:GetDataStore("GardenTrades" .. D().storeSuffix())
		end)
		store = if ok then s else nil
	end
	return store
end

local function keyFor(userId: number): string
	return `player_{userId}`
end

-- Ledger writes (V1.4 step 2), 3 tries each like Profiles; false when the store is unavailable.
local function ledgerAppend(userId: number, L: Ledger): boolean
	local s = ledgerStore()
	if s == nil then
		return false
	end
	return (
		D().withRetries(`ledger {userId}`, function()
			return s:UpdateAsync(keyFor(userId), function(list: any)
				local out = if type(list) == "table" then table.clone(list) else {}
				table.insert(out, L)
				while #out > TRADE.kept do
					table.remove(out, 1)
				end
				return out
			end)
		end)
	)
end

local function ledgerMark(userId: number, id: string, fields: { [string]: any }): boolean
	local s = ledgerStore()
	if s == nil then
		return false
	end
	return (
		D().withRetries(`ledger mark {userId}`, function()
			return s:UpdateAsync(keyFor(userId), function(list: any)
				local out = if type(list) == "table" then table.clone(list) else {}
				for i, rec in out do
					if type(rec) == "table" and rec.id == id then
						local copy = table.clone(rec)
						for k, v in fields do
							copy[k] = v
						end
						out[i] = copy
					end
				end
				return out
			end)
		end)
	)
end

local function ledgerRead(userId: number): { Ledger }?
	local s = ledgerStore()
	if s == nil then
		return nil
	end
	local ok, list = D().withRetries(`ledger read {userId}`, function()
		return s:GetAsync(keyFor(userId))
	end)
	if not ok then
		return nil
	end
	return if type(list) == "table" then list else {}
end

-- Live trades ---------------------------------------------------------------------------------

local function other(pair: Pair, player: Player): Player
	return if pair.a == player then pair.b else pair.a
end

local function recordOf(profile: Profile?, id: string?): GardenConfig.TradeRecord?
	if profile == nil or id == nil then
		return nil
	end
	for _, r in profile.trades do
		if r.id == id then
			return r
		end
	end
	return nil
end

-- The `trade` Fx to both players (architecture 5.1), each with its own record on done.
local function send(pair: Pair)
	local d = D()
	local names = { [pair.a.UserId] = pair.a.DisplayName, [pair.b.UserId] = pair.b.DisplayName }
	local pa, pb = d.get(pair.a), d.get(pair.b)
	local creatures = {
		[pair.a.UserId] = if pa and pair.t.a.pick then GardenRules.find(pa, pair.t.a.pick) else nil,
		[pair.b.UserId] = if pb and pair.t.b.pick then GardenRules.find(pb, pair.t.b.pick) else nil,
	}
	for _, player in { pair.a, pair.b } do
		local payload = TradeRules.status(pair.t, names, creatures)
		if pair.t.state == "done" then
			payload.record = recordOf(d.get(player), pair.t.id)
		end
		d.send(player, "trade", payload)
	end
end

local function drop(pair: Pair)
	if live[pair.a] == pair then
		live[pair.a] = nil
	end
	if live[pair.b] == pair then
		live[pair.b] = nil
	end
end

-- Ends a live trade: the pair is sent its final state and forgotten. A player who declines or
-- cancels is not proposable by the other for TRADE.declineGap (State.Live.declined).
local function cancel(pair: Pair, reason: string, by: Player?)
	if pair.t.state == "cancelled" or pair.t.state == "done" then
		return
	end
	local t = table.clone(pair.t)
	t.state = "cancelled"
	t.reason = reason
	t.at = 0
	pair.t = t
	if by then
		local victim = State.live[other(pair, by)]
		if victim then
			victim.declined[by.UserId] = os.time()
		end
	end
	send(pair)
	drop(pair)
end

local function within(a: Player, b: Player): boolean
	local ra, rb = D().rootPos(a), D().rootPos(b)
	return ra ~= nil and rb ~= nil and GardenRules.within(ra, rb, TRADE.range)
end

local function unfairNotice(pair: Pair, side: number?)
	local loser = if side == 1 then pair.a else pair.b
	for _, player in { pair.a, pair.b } do
		D().notice(player, `That trade would not be fair to {loser.DisplayName}`)
	end
end

-- V1.1 checks, then TradeRules.new; sends `trade` to both.
function Trades.propose(player: Player, targetUserId: number): boolean
	local d = D()
	local target = d.playerOf(targetUserId)
	local mine = State.live[player]
	if closed or target == nil or target == player or mine == nil or State.live[target] == nil then
		return false
	end
	if live[player] then
		return false
	end
	if live[target] then
		d.notice(player, `{target.DisplayName} is already trading.`)
		return false
	end
	local now = os.time()
	local declinedAt = mine.declined[target.UserId]
	if declinedAt and now - declinedAt < TRADE.declineGap then
		d.notice(player, `Give {target.DisplayName} a moment before asking again.`)
		return false
	end
	if not (d.isFriend(player, target) and d.isFriend(target, player)) then
		d.notice(player, FRIENDS_TEXT)
		return false
	end
	-- The friend lookup may have yielded: everything below reads the current state.
	if live[player] or live[target] or d.get(player) == nil or d.get(target) == nil then
		return false
	end
	if not within(player, target) then
		d.notice(player, `Stand next to {target.DisplayName} to trade.`)
		return false
	end
	if not (d.isOnline(player) and d.isOnline(target)) then
		d.notice(player, ONLINE_TEXT)
		return false
	end
	local today = MetaRules.dayOf(now)
	if not TradeRules.canTrade(d.get(player) :: Profile, today) then
		d.notice(player, LIMIT_TEXT)
		return false
	elseif not TradeRules.canTrade(d.get(target) :: Profile, today) then
		d.notice(player, `{target.DisplayName} has done today's trades. More tomorrow!`)
		return false
	end
	local pair: Pair = { t = TradeRules.new(player.UserId, target.UserId, now), a = player, b = target }
	live[player] = pair
	live[target] = pair
	send(pair)
	return true
end

-- Commit sequence (V1.4): one thread per trade. Both ledger keys first; then the re-check and the
-- two applies in one step with no yield between them.
local function commit(pair: Pair)
	local d = D()
	local a, b = pair.a, pair.b
	local now = os.time()
	local today = MetaRules.dayOf(now)
	local pa, pb = d.get(a), d.get(b)
	if pa == nil or pb == nil then
		cancel(pair, "left")
		return
	end
	local ok, reason, side = TradeRules.canCommit(pa, pb, pair.t, today)
	if not ok then
		if reason == "unfair" then
			unfairNotice(pair, side)
		end
		cancel(pair, reason :: string)
		return
	end
	local id = string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 16)
	local L = TradeRules.ledger(pair.t, pa, pb, id, now)
	if not ledgerAppend(a.UserId, L) then
		cancel(pair, "failed")
		return
	end
	if not ledgerAppend(b.UserId, L) then
		cancel(pair, "failed")
		task.spawn(ledgerMark, a.UserId, id, { void = true })
		return
	end
	-- Both profiles may have changed during the yields.
	pa, pb = d.get(a), d.get(b)
	local function void()
		task.spawn(ledgerMark, a.UserId, id, { void = true })
		task.spawn(ledgerMark, b.UserId, id, { void = true })
	end
	if pa == nil or pb == nil or not (d.isOnline(a) and d.isOnline(b)) then
		void()
		cancel(pair, if pa == nil or pb == nil then "left" else "offline")
		return
	end
	ok, reason, side = TradeRules.canCommit(pa, pb, pair.t, today)
	if not ok then
		void()
		if reason == "unfair" then
			unfairNotice(pair, side)
		end
		cancel(pair, reason :: string)
		return
	end
	-- No yield from here to the end of the function.
	d.apply(a, "trade", function(p)
		return TradeRules.give(p, a.UserId, L, today)
	end)
	d.apply(b, "trade", function(p)
		return TradeRules.give(p, b.UserId, L, today)
	end)
	local t = table.clone(pair.t)
	t.state = "done"
	t.id = id
	t.at = 0
	pair.t = t
	print(`[Trades] {id}: {a.UserId} gave {L.ca.id}, {b.UserId} gave {L.cb.id}`)
	send(pair)
	drop(pair)
end

-- The tradeAccept, tradeCancel, tradeConfirm, tradePick and tradeEmote actions.
function Trades.act(player: Player, action: TradeRules.Action, arg: number?): boolean
	local d = D()
	local pair = live[player]
	if pair == nil or closed then
		return false
	end
	local now = os.time()
	if action == "cancel" then
		if pair.t.state == "committing" then
			return false
		end
		cancel(pair, if pair.t.state == "proposed" and player == pair.b then "declined" else "cancelled", player)
		return true
	end
	local partner = other(pair, player)
	if action ~= "emote" and not within(player, partner) then
		d.notice(player, `Stand next to {partner.DisplayName} to trade.`)
		return false
	end
	local pa, pb = d.get(pair.a), d.get(pair.b)
	if pa == nil or pb == nil then
		return false
	end
	if action == "pick" then
		local c, why = TradeRules.tradable(d.get(player) :: Profile, arg or 0)
		if c == nil then
			if why == "fav" then
				d.notice(player, "A favourite cannot be traded. Unfavourite it first.")
			end
			return false
		end
	elseif action == "accept" and pair.t.state == "picking" then
		-- The TRADE button: the fairness and limit checks run now, so the refusal is immediate.
		local ok, reason, side = TradeRules.canCommit(pa, pb, pair.t, MetaRules.dayOf(now))
		if not ok then
			if reason == "unfair" then
				unfairNotice(pair, side)
			elseif reason == "limit" then
				d.notice(player, LIMIT_TEXT)
			end
			return false
		end
	end
	local t, ok = TradeRules.step(pair.t, player.UserId, action, arg, now)
	if not ok then
		return false
	end
	pair.t = t
	if action == "emote" then
		d.send(partner, "tradeEmote", { by = player.UserId, emote = arg })
		return true
	end
	if action == "pick" and t.a.pick and t.b.pick then
		local ca = GardenRules.find(pa, t.a.pick) :: Creature?
		local cb = GardenRules.find(pb, t.b.pick) :: Creature?
		local side = if ca and cb then TradeRules.unfairTo(ca, cb) else 0
		if side ~= 0 then
			unfairNotice(pair, side)
		end
	end
	send(pair)
	if t.state == "committing" then
		task.spawn(commit, pair)
	end
	return true
end

-- Undo sequence (V1.5): both present and online, canUndo on both current profiles, undoAt on both
-- ledger keys, then the two applies with no yield.
function Trades.undo(player: Player, id: string): boolean
	local d = D()
	local profile = d.get(player)
	local r = recordOf(profile, id)
	if closed or profile == nil or r == nil then
		return false
	end
	local partner = d.playerOf(r.with)
	local theirs = partner and d.get(partner)
	if partner == nil or theirs == nil or not (d.isOnline(player) and d.isOnline(partner)) then
		d.notice(player, UNDO_BOTH_TEXT)
		return false
	end
	local now = os.time()
	for _, p in { profile, theirs } do
		local ok, why = TradeRules.canUndo(p, id, now)
		if not ok then
			if why == "released" then
				d.notice(player, UNDO_RELEASED_TEXT)
			end
			return false
		end
	end
	local L: Ledger = { id = id, at = r.at, a = player.UserId, b = partner.UserId, ca = r.gave, cb = r.got }
	if not ledgerMark(player.UserId, id, { undoAt = now }) or not ledgerMark(partner.UserId, id, { undoAt = now }) then
		d.notice(player, UNDO_RETRY_TEXT)
		return false
	end
	-- No yield from here.
	d.apply(player, "tradeUndo", function(p)
		return TradeRules.undo(p, player.UserId, L)
	end)
	d.apply(partner, "tradeUndo", function(p)
		return TradeRules.undo(p, partner.UserId, L)
	end)
	local names = { [player.UserId] = player.DisplayName, [partner.UserId] = partner.DisplayName }
	for _, p in { player, partner } do
		d.send(p, "trade", {
			state = "undone",
			id = id,
			at = 0,
			a = { user = player.UserId, name = names[player.UserId], ready = false, confirmed = false },
			b = { user = partner.UserId, name = names[partner.UserId], ready = false, confirmed = false },
			record = recordOf(d.get(p), id),
		})
	end
	local species = GardenConfig.species(r.got.s)
	d.notice(
		partner,
		`{player.DisplayName} changed their mind, so your {if species then species.name else r.got.s} came back to you`
	)
	print(`[Trades] {id} undone by {player.UserId}`)
	return true
end

-- The creature is picked in a live trade (the router refuses release, store, place, favourite, name).
function Trades.locked(player: Player, id: number): boolean
	local pair = live[player]
	if pair == nil then
		return false
	end
	local mine = TradeRules.side(pair.t, player.UserId)
	return mine ~= nil and mine.pick == id
end

-- 1 Hz: timers, then presence and distance; committing pairs are the commit thread's.
function Trades.step(now: number)
	local d = D()
	local seen: { [Pair]: boolean } = {}
	for _, pair in live do
		if seen[pair] or pair.t.state == "committing" then
			continue
		end
		seen[pair] = true
		local t = TradeRules.tick(pair.t, now)
		if t.state == "cancelled" then
			cancel(pair, t.reason :: string)
			continue
		end
		if d.get(pair.a) == nil or d.get(pair.b) == nil then
			cancel(pair, "left")
		elseif not (d.isOnline(pair.a) and d.isOnline(pair.b)) then
			cancel(pair, "offline")
		elseif not within(pair.a, pair.b) then
			cancel(pair, "apart")
		elseif t ~= pair.t then
			pair.t = t
			send(pair)
		end
	end
end

-- PlayerRemoving: a leaver's trade ends for both.
function Trades.leave(player: Player)
	local pair = live[player]
	if pair and pair.t.state ~= "committing" then
		cancel(pair, "left")
	end
end

-- Heal (V1.4 step 4) from Profiles.load, after login and before the player can act. Reads this
-- player's ledger; for each record missing from `trades` (or carrying an undo the profile lacks)
-- it reads the counterpart's key, so every lookup is resolved before the one apply, which never
-- yields. A DataStore failure skips the heal; the next load tries again.
function Trades.heal(player: Player, profile: Profile)
	local d = D()
	local uid = player.UserId
	local mine = ledgerRead(uid)
	if mine == nil or #mine == 0 then
		return
	end
	local others: { [number]: { [string]: Ledger }? } = {} -- counterpart UserId -> their records by id
	local function counterpart(L: Ledger): Ledger?
		local who = if L.a == uid then L.b else L.a
		if others[who] == nil then
			local list = ledgerRead(who)
			local byId = {}
			for _, rec in list or {} do
				byId[rec.id] = rec
			end
			others[who] = byId
		end
		return (others[who] :: { [string]: Ledger })[L.id]
	end
	-- An undo mark counts only when both copies carry it (the undo sequence marks a first, then b),
	-- so a half-marked undo never returns one creature without the other.
	local resolved: { Ledger } = {}
	local confirmed: { [string]: boolean } = {}
	for _, L in mine do
		if type(L) ~= "table" or L.void then
			continue
		end
		local r = recordOf(profile, L.id)
		local copy = table.clone(L)
		if r == nil or (L.undoAt and not r.undone) then
			local theirs = counterpart(L)
			confirmed[L.id] = theirs ~= nil
			if L.undoAt and (theirs == nil or theirs.undoAt == nil) then
				copy.undoAt = nil
			end
		end
		table.insert(resolved, copy)
	end
	local now = os.time()
	local function confirmedSync(L: Ledger): boolean
		return confirmed[L.id] == true
	end
	local healed = TradeRules.heal(profile, uid, resolved, confirmedSync, now)
	if healed == profile then
		return
	end
	local ids = {}
	for _, r in healed.trades do
		local before = recordOf(profile, r.id)
		if before == nil or before.undone ~= r.undone then
			table.insert(ids, r.id)
		end
	end
	warn(`[Trades] healed {uid}: {table.concat(ids, " ")}`)
	d.apply(player, "tradeHeal", function(p)
		return TradeRules.heal(p, uid, resolved, confirmedSync, now)
	end)
end

-- BindToClose: every live trade ends; a commit past its ledger writes still finishes its applies.
function Trades.close()
	closed = true
	for _, pair in table.clone(live) do
		if pair.t.state ~= "committing" then
			cancel(pair, "left")
		end
	end
end

return Trades
