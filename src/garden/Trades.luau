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

-- L and applying are set by the commit thread, so its error guard knows how far it got (QA m8).
type Pair = { t: Trade, a: Player, b: Player, L: Ledger?, applying: boolean? }

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
-- "<UserId>:<creature id>" of the two received creatures while an undo returns them (QA M2).
local held: { [string]: boolean } = {}
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

-- Sets (or, with value nil, clears) one field of record `id` in a player's ledger key.
local function ledgerMark(userId: number, id: string, field: string, value: any): boolean
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
						copy[field] = value
						out[i] = copy
					end
				end
				return out
			end)
		end)
	)
end

-- A mark that must land (a void, or an undo mark taken back): retried for about two and a half
-- minutes, then a warn with the trade id for a person to check (QA B1, M2).
local MARK_WAITS = { 10, 20, 40, 80 }
local function markUntil(userId: number, id: string, field: string, value: any)
	for attempt = 1, #MARK_WAITS + 1 do
		if ledgerMark(userId, id, field, value) then
			return
		end
		if attempt <= #MARK_WAITS then
			task.wait(MARK_WAITS[attempt])
		end
	end
	warn(`[Trades] ledger {userId}: could not set {field} on trade {id}; check this trade by hand`)
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
		return nil -- failed, which the heal keeps apart from an absent key ({}) (QA M1)
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

-- V1.4 step 3: the two applies, never yielding between them.
local function applyBoth(pair: Pair, L: Ledger, today: number)
	for _, player in { pair.a, pair.b } do
		D().apply(player, "trade", function(p)
			return TradeRules.give(p, player.UserId, L, today)
		end)
	end
end

local function markDone(pair: Pair, id: string)
	local t = table.clone(pair.t)
	t.state = "done"
	t.id = id
	t.at = 0
	pair.t = t
	send(pair)
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
	pair.L = L
	-- Voids both copies: a write that landed but reported failure is voided too (QA B1).
	local function void()
		task.spawn(markUntil, a.UserId, id, "void", true)
		task.spawn(markUntil, b.UserId, id, "void", true)
	end
	if not ledgerAppend(a.UserId, L) then
		cancel(pair, "failed")
		return
	end
	if not ledgerAppend(b.UserId, L) then
		cancel(pair, "failed")
		void()
		return
	end
	-- Both profiles may have changed during the yields.
	pa, pb = d.get(a), d.get(b)
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
	pair.applying = true
	applyBoth(pair, L, today)
	print(`[Trades] {id}: {a.UserId} gave {L.ca.id}, {b.UserId} gave {L.cb.id}`)
	markDone(pair, id)
	drop(pair)
end

-- The commit thread under an error guard (QA m8). Before the applies nothing changed: void what the
-- ledger holds and cancel "failed", which tells both players. Once the applies began the trade
-- stands: finish both halves (give is idempotent on the id). Either way the pair is dropped.
local function commitGuarded(pair: Pair)
	local ok, err = pcall(commit, pair)
	if ok then
		return
	end
	warn(`[Trades] commit {pair.a.UserId} {pair.b.UserId} failed: {tostring(err)}`)
	local L = pair.L
	if L and pair.applying then
		pcall(applyBoth, pair, L, MetaRules.dayOf(L.at))
		if pair.t.state ~= "done" then
			pcall(markDone, pair, L.id)
		end
	else
		if L then
			task.spawn(markUntil, pair.a.UserId, L.id, "void", true)
			task.spawn(markUntil, pair.b.UserId, L.id, "void", true)
		end
		pcall(cancel, pair, "failed")
	end
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
		if c == nil or held[`{player.UserId}:{arg}`] then -- an undo is returning it (QA M2)
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
		task.spawn(commitGuarded, pair)
	end
	return true
end

-- Both players here with saving on, and canUndo on both current profiles; else the reason.
local function undoable(player: Player, partner: Player, id: string, now: number): (boolean, string?)
	local d = D()
	local mine, theirs = d.get(player), d.get(partner)
	if mine == nil or theirs == nil or not (d.isOnline(player) and d.isOnline(partner)) then
		return false, "both"
	end
	for _, p in { mine, theirs } do
		local ok, why = TradeRules.canUndo(p, id, now)
		if not ok then
			return false, why
		end
	end
	return true, nil
end

-- Undo sequence (V1.5): both present and online, canUndo on both current profiles, undoAt on both
-- ledger keys, canUndo again (the marks yield), then the two applies with no yield. Returns
-- "done", "retry" (nothing marked) or "strip" (an undo mark may have landed and must be taken back).
local function undoMarked(player: Player, partner: Player, r: GardenConfig.TradeRecord, now: number): string
	local d = D()
	local id = r.id
	if not ledgerMark(player.UserId, id, "undoAt", now) then
		return "retry"
	end
	if not ledgerMark(partner.UserId, id, "undoAt", now) or not undoable(player, partner, id, now) then
		return "strip"
	end
	-- No yield from here.
	local L: Ledger = { id = id, at = r.at, a = player.UserId, b = partner.UserId, ca = r.gave, cb = r.got }
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
	return "done"
end

-- tradeUndo: refused while either player trades (QA M2); both received creatures stay locked
-- (Trades.locked) from the first check to the applies, and after a "strip" until both undo marks
-- are taken back, so no second undo can be marked under them.
function Trades.undo(player: Player, id: string): boolean
	local d = D()
	local r = recordOf(d.get(player), id)
	local partner = r and d.playerOf(r.with)
	if closed or r == nil then
		return false
	elseif partner == nil then
		d.notice(player, UNDO_BOTH_TEXT)
		return false
	end
	local theirs = recordOf(d.get(partner), id)
	local keys = { `{player.UserId}:{r.gotId}`, `{partner.UserId}:{if theirs then theirs.gotId else 0}` }
	if live[player] or live[partner] or held[keys[1]] or held[keys[2]] then
		d.notice(player, UNDO_RETRY_TEXT)
		return false
	end
	local now = os.time()
	local ok, why = undoable(player, partner, id, now)
	if not ok then
		if why == "both" then
			d.notice(player, UNDO_BOTH_TEXT)
		elseif why == "released" then
			d.notice(player, UNDO_RELEASED_TEXT)
		end
		return false
	end
	held[keys[1]], held[keys[2]] = true, true
	local ran, result = pcall(undoMarked, player, partner, r, now)
	if ran and result == "strip" then
		task.spawn(function()
			markUntil(player.UserId, id, "undoAt", nil)
			markUntil(partner.UserId, id, "undoAt", nil)
			held[keys[1]], held[keys[2]] = nil, nil
		end)
	else
		held[keys[1]], held[keys[2]] = nil, nil
	end
	if not ran then
		warn(`[Trades] undo {id} failed: {tostring(result)}`)
	elseif result ~= "done" then
		d.notice(player, UNDO_RETRY_TEXT)
	end
	return ran and result == "done"
end

-- The creature is picked in a live trade, or an undo is returning it (the router refuses release,
-- store, place, favourite, name).
function Trades.locked(player: Player, id: number): boolean
	if held[`{player.UserId}:{id}`] then
		return true
	end
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
-- yields. Returns false when a ledger read failed (own key or a counterpart's): nothing is applied
-- and Profiles.load starts the session offline, so nothing writes until a later load heals (QA M1).
function Trades.heal(player: Player, profile: Profile): boolean
	local d = D()
	local uid = player.UserId
	local mine = ledgerRead(uid)
	if mine == nil then
		return false
	elseif #mine == 0 then
		return true
	end
	local others: { [number]: { [string]: Ledger }? } = {} -- counterpart UserId -> their records by id
	local failed = false
	local function counterpart(L: Ledger): Ledger?
		local who = if L.a == uid then L.b else L.a
		if others[who] == nil then
			local list = ledgerRead(who)
			if list == nil then
				failed = true
				return nil
			end
			local byId = {}
			for _, rec in list do
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
			if failed then
				return false
			end
			confirmed[L.id] = TradeRules.confirms(theirs)
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
		return true
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
	return true
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
