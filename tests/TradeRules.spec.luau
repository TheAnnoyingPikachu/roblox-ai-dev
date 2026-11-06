--!strict
local T = require("./framework")
local GardenConfig = require("../src/shared/GardenConfig")
local GardenProgress = require("../src/shared/GardenProgress")
local GardenRules = require("../src/shared/GardenRules")
local MetaRules = require("../src/shared/MetaRules")
local TradeRules = require("../src/shared/TradeRules")

local describe, it, expect = T.describe, T.it, T.expect

type Profile = GardenConfig.Profile
type Creature = GardenConfig.Creature

local NOW = 1_800_000_000
local DAY = MetaRules.dayOf(NOW)
local A, B = 1001, 2002
local ID = "0123456789abcdef"

local function same(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function creature(id: number, s: string, m: string, z: string, placed: number, c: string?): Creature
	return { id = id, s = s, m = m, z = z, c = c or "none", placed = placed, fav = false, fa = 0, n = "" }
end

-- A: a Big Golden Berry Cat (54) on pad 1, a Sprout Bunny (1) on pad 2, a stored Frog (2).
local function profileA(): Profile
	local p = GardenProgress.defaults(NOW)
	p.creatures = { creature(1, "cat", "golden", "big", 1), creature(2, "bunny", "normal", "normal", 2) }
	table.insert(p.creatures, creature(3, "frog", "normal", "normal", 0))
	p.creatures[1].n = "Sprinkles"
	p.index = { "cat:golden", "bunny:normal", "frog:normal" }
	p.nextId = 4
	p.xp = 500
	p.coins = 777
	return p
end

-- B: a Normal Acorn Hedgehog (45) on pad 3, a Normal Moth on pad 1, a favourite Fox.
local function profileB(): Profile
	local p = GardenProgress.defaults(NOW)
	p.creatures = { creature(5, "hedgehog", "normal", "normal", 3), creature(6, "moth", "normal", "normal", 1) }
	table.insert(p.creatures, creature(7, "fox", "normal", "normal", 2))
	p.creatures[3].fav = true
	p.creatures[1].n = "Pebble"
	p.index = { "hedgehog:normal", "moth:normal", "fox:normal" }
	p.nextId = 8
	p.xp = 900
	p.coins = 123
	return p
end

-- A trade in `picking` with A's cat (54) and B's hedgehog (45) picked.
local function picked(): TradeRules.Trade
	local t = TradeRules.new(A, B, NOW)
	t = TradeRules.step(t, B, "accept", nil, NOW + 1)
	t = TradeRules.step(t, A, "pick", 1, NOW + 2)
	t = TradeRules.step(t, B, "pick", 5, NOW + 3)
	return t
end

local function committing(): TradeRules.Trade
	local t = picked()
	t = TradeRules.step(t, A, "accept", nil, NOW + 4)
	t = TradeRules.step(t, B, "accept", nil, NOW + 5)
	t = TradeRules.tick(t, NOW + 15)
	t = TradeRules.step(t, A, "confirm", nil, NOW + 16)
	t = TradeRules.step(t, B, "confirm", nil, NOW + 17)
	return t
end

local function ledger(): TradeRules.Ledger
	return TradeRules.ledger(committing(), profileA(), profileB(), ID, NOW + 20)
end

local function summary(t: TradeRules.Trade): string
	return `{t.state} {t.a.pick or "-"}{t.a.ready and "r" or ""}{t.a.confirmed and "c" or ""} `
		.. `{t.b.pick or "-"}{t.b.ready and "r" or ""}{t.b.confirmed and "c" or ""} {t.at} {t.reason or "-"}`
end

describe("TradeRules state machine (V1.3)", function()
	it("walks proposed, picking, hold, confirm, committing with the V1.8 time limits", function()
		local t = TradeRules.new(A, B, NOW)
		expect(summary(t)).toBe(`proposed - - {NOW + 30} -`)
		local mine, theirs = TradeRules.side(t, B)
		expect(`{(mine :: any).user} {(theirs :: any).user}`).toBe(`{B} {A}`)
		expect(TradeRules.side(t, 3)).toBeNil()
		local ok, reason
		t, ok, reason = TradeRules.step(t, B, "accept", nil, NOW + 1)
		expect(`{ok} {reason} {summary(t)}`).toBe(`true nil picking - - {NOW + 121} -`)
		t = TradeRules.step(t, A, "pick", 1, NOW + 2)
		t = TradeRules.step(t, B, "pick", 5, NOW + 3)
		expect(summary(t)).toBe(`picking 1 5 {NOW + 121} -`)
		t, ok = TradeRules.step(t, A, "accept", nil, NOW + 4)
		expect(`{ok} {summary(t)}`).toBe(`true picking 1r 5 {NOW + 121} -`)
		t, ok = TradeRules.step(t, B, "accept", nil, NOW + 5)
		expect(`{ok} {summary(t)}`).toBe(`true hold 1r 5r {NOW + 15} -`)
		expect(TradeRules.tick(t, NOW + 14)).toBe(t)
		t = TradeRules.tick(t, NOW + 15)
		expect(summary(t)).toBe(`confirm 1r 5r {NOW + 35} -`)
		t, ok = TradeRules.step(t, B, "confirm", nil, NOW + 16)
		expect(`{ok} {summary(t)}`).toBe(`true confirm 1r 5rc {NOW + 35} -`)
		t, ok = TradeRules.step(t, A, "confirm", nil, NOW + 17)
		expect(`{ok} {summary(t)}`).toBe("true committing 1rc 5rc 0 -")
		expect(TradeRules.tick(t, NOW + 9999)).toBe(t) -- no timer past committing
	end)

	it(
		"refuses the wrong user, the wrong state and an accept without both picks, leaving the trade as it was",
		function()
			local t = TradeRules.new(A, B, NOW)
			local function refused(user: number, action: TradeRules.Action, arg: number?, want: string)
				local out, ok, reason = TradeRules.step(t, user, action, arg, NOW + 1)
				expect(`{action} {ok} {reason}`).toBe(`{action} false {want}`)
				expect(out).toBe(t)
			end
			refused(A, "accept", nil, "user") -- only B accepts the invite
			refused(3, "accept", nil, "user")
			refused(3, "cancel", nil, "user")
			refused(A, "pick", 1, "state")
			refused(A, "confirm", nil, "state")
			t = TradeRules.step(t, B, "accept", nil, NOW + 1)
			refused(A, "accept", nil, "pick") -- nobody has picked
			refused(A, "confirm", nil, "state")
			refused(A, "pick", nil, "range")
			t = TradeRules.step(t, A, "pick", 1, NOW + 2)
			refused(B, "accept", nil, "pick") -- B has not picked
			t = TradeRules.step(t, B, "pick", 5, NOW + 2)
			t = TradeRules.step(t, A, "accept", nil, NOW + 3)
			t = TradeRules.step(t, B, "accept", nil, NOW + 3)
			refused(A, "confirm", nil, "state") -- the hold bar has not ended
			refused(A, "pick", 1, "state")
			refused(A, "accept", nil, "state")
			t = TradeRules.tick(t, NOW + 13)
			refused(A, "pick", 1, "state")
			refused(A, "accept", nil, "state")
			t = TradeRules.step(t, A, "confirm", nil, NOW + 14)
			refused(A, "pick", 1, "state") -- picks are closed once confirming starts
			expect(select(2, TradeRules.step(t, A, "confirm", nil, NOW + 15))).toBe(true) -- a second press is harmless
		end
	)

	it("clears both TRADE presses when either pick changes", function()
		local t = picked()
		t = TradeRules.step(t, A, "accept", nil, NOW + 4)
		expect(t.a.ready).toBe(true)
		t = TradeRules.step(t, B, "pick", 6, NOW + 5)
		expect(`{t.a.ready} {t.b.ready} {t.b.pick} {t.state}`).toBe("false false 6 picking")
		t = TradeRules.step(t, B, "accept", nil, NOW + 6)
		t = TradeRules.step(t, A, "pick", 2, NOW + 7)
		expect(`{t.a.ready} {t.b.ready} {t.a.pick} {t.state}`).toBe("false false 2 picking")
	end)

	it("lets either player cancel in every state before committing, declined only by B on the invite", function()
		local t = TradeRules.new(A, B, NOW)
		expect(summary(TradeRules.step(t, B, "cancel", nil, NOW + 1))).toBe("cancelled - - 0 declined")
		expect(summary(TradeRules.step(t, A, "cancel", nil, NOW + 1))).toBe("cancelled - - 0 cancelled")
		t = picked()
		expect(summary(TradeRules.step(t, B, "cancel", nil, NOW + 1))).toBe("cancelled 1 5 0 cancelled")
		t = TradeRules.step(t, A, "accept", nil, NOW + 4)
		t = TradeRules.step(t, B, "accept", nil, NOW + 5)
		expect((TradeRules.step(t, A, "cancel", nil, NOW + 6)).state).toBe("cancelled") -- hold
		t = TradeRules.tick(t, NOW + 15)
		expect((TradeRules.step(t, B, "cancel", nil, NOW + 16)).state).toBe("cancelled") -- confirm
		t = TradeRules.step(t, A, "confirm", nil, NOW + 16)
		expect((TradeRules.step(t, B, "cancel", nil, NOW + 17)).state).toBe("cancelled") -- one confirm in
		t = TradeRules.step(t, B, "confirm", nil, NOW + 17)
		local out, ok, reason = TradeRules.step(t, B, "cancel", nil, NOW + 18)
		expect(`{out.state} {ok} {reason}`).toBe("committing false state")
		local done = TradeRules.step(picked(), A, "cancel", nil, NOW + 1)
		for _, action in { "accept", "pick", "confirm", "cancel", "emote" } do
			local _, refused, why = TradeRules.step(done, A, action :: any, 1, NOW + 2)
			expect(`{action} {refused} {why}`).toBe(`{action} false state`)
		end
		expect(TradeRules.tick(done, NOW + 99999)).toBe(done)
	end)

	it("expires proposed at 30 s, picking at 120 s and confirm at 20 s, and ends the hold at 10 s", function()
		local t = TradeRules.new(A, B, NOW)
		expect(TradeRules.tick(t, NOW + 29)).toBe(t)
		expect(summary(TradeRules.tick(t, NOW + 30))).toBe("cancelled - - 0 expired")
		t = TradeRules.step(t, B, "accept", nil, NOW + 10)
		expect(TradeRules.tick(t, NOW + 129)).toBe(t)
		expect(TradeRules.tick(t, NOW + 130).reason).toBe("expired")
		t = picked()
		t = TradeRules.step(t, A, "accept", nil, NOW + 20) -- one press keeps the picking clock
		expect(TradeRules.tick(t, NOW + 121).state).toBe("cancelled")
		t = TradeRules.step(t, B, "accept", nil, NOW + 20)
		expect(TradeRules.tick(t, NOW + 29).state).toBe("hold")
		t = TradeRules.tick(t, NOW + 30)
		expect(`{t.state} {t.at}`).toBe(`confirm {NOW + 50}`)
		expect(TradeRules.tick(t, NOW + 49)).toBe(t)
		expect(summary(TradeRules.tick(t, NOW + 50))).toBe("cancelled 1r 5r 0 expired")
		t = TradeRules.step(t, A, "confirm", nil, NOW + 40)
		expect(TradeRules.tick(t, NOW + 50).state).toBe("cancelled") -- one confirm is not enough
	end)

	it("forwards 1 to 4 emotes at most once a second per player without changing the state", function()
		local t = picked()
		local out, ok, reason = TradeRules.step(t, A, "emote", 2, NOW + 5)
		expect(`{ok} {reason} {out.state} {out.emoteAt[A]}`).toBe(`true nil picking {NOW + 5}`)
		expect(t.emoteAt[A]).toBeNil() -- input unchanged
		local _, again, gap = TradeRules.step(out, A, "emote", 1, NOW + 5.5)
		expect(`{again} {gap}`).toBe("false gap")
		expect(select(2, TradeRules.step(out, B, "emote", 4, NOW + 5.5))).toBe(true) -- per player
		expect(select(2, TradeRules.step(out, A, "emote", 3, NOW + 6))).toBe(true)
		for _, bad in { 0, 5, 1.5, -1 } do
			local _, refused, why = TradeRules.step(out, A, "emote", bad, NOW + 7)
			expect(`{bad} {refused} {why}`).toBe(`{bad} false range`)
		end
		expect(select(3, TradeRules.step(out, A, "emote", nil, NOW + 7))).toBe("range")
		expect(select(2, TradeRules.step(committing(), A, "emote", 1, NOW + 30))).toBe(false)
		expect(select(2, TradeRules.step(TradeRules.new(A, B, NOW), A, "emote", 1, NOW))).toBe(true)
	end)

	it("never mutates the trade it is given", function()
		local t = picked()
		local frozen = summary(t)
		TradeRules.step(t, A, "accept", nil, NOW + 4)
		TradeRules.step(t, A, "pick", 2, NOW + 4)
		TradeRules.step(t, A, "cancel", nil, NOW + 4)
		TradeRules.step(t, A, "emote", 1, NOW + 4)
		TradeRules.tick(t, NOW + 999)
		expect(summary(t)).toBe(frozen)
		expect(next(t.emoteAt)).toBeNil()
	end)
end)

describe("TradeRules fairness and picks (V1.2)", function()
	it("values a creature as GardenRules.rate, charm and size included", function()
		local c = creature(1, "cat", "golden", "big", 1, "stormy")
		expect(TradeRules.value(c)).toBe(12 * 3 * 1.5 * 3)
		expect(TradeRules.value(c)).toBe(GardenRules.rate(c))
	end)

	it("allows exactly 50% and refuses just under, naming the side that gives more", function()
		local hundred = creature(1, "lion", "normal", "normal", 1, "none") -- 500
		local half = creature(2, "deer", "normal", "normal", 1) -- 250
		local under = creature(3, "turtle", "normal", "normal", 1) -- 180
		expect(TradeRules.fair(hundred, half)).toBe(true)
		expect(TradeRules.fair(half, hundred)).toBe(true)
		expect(TradeRules.unfairTo(hundred, half)).toBe(0)
		expect(TradeRules.fair(hundred, under)).toBe(false)
		expect(TradeRules.unfairTo(hundred, under)).toBe(1)
		expect(TradeRules.unfairTo(under, hundred)).toBe(2)
		-- A Big Frosted Bunny (1 x 1.5 x 1.5 = 2.25) against a Frog (2) and a Normal Pup (5).
		local bunny = creature(4, "bunny", "normal", "big", 1, "frosted")
		expect(TradeRules.value(bunny)).toBe(2.25)
		expect(TradeRules.fair(bunny, creature(5, "frog", "normal", "normal", 1))).toBe(true)
		expect(TradeRules.fair(bunny, creature(5, "pup", "normal", "normal", 1))).toBe(false) -- 2.25 < 2.5
		expect(TradeRules.fair(bunny, creature(5, "pup", "normal", "normal", 1, "frosted"))).toBe(false) -- 7.5
		-- Exactly half with a charm on the cheaper side: Stormy Bunny (3) against a Frog x1.5 (3)... 6 vs 3.
		expect(
			TradeRules.fair(
				creature(6, "bunny", "normal", "normal", 1, "stormy"),
				creature(7, "duck", "normal", "normal", 1, "blooming")
			)
		).toBe(true) -- 3 vs 6
		expect(
			TradeRules.fair(
				creature(6, "bunny", "normal", "normal", 1, "stormy"),
				creature(7, "duck", "normal", "big", 1, "blooming")
			)
		).toBe(false) -- 3 vs 9
		expect(TradeRules.fair(creature(8, "nope", "normal", "normal", 1), creature(9, "bunny", "normal", "normal", 1))).toBe(
			false
		) -- 0 vs 1
	end)

	it("lets only owned, non-favourite creatures be picked", function()
		local b = profileB()
		local c, reason = TradeRules.tradable(b, 5)
		expect(`{(c :: any).id} {reason}`).toBe("5 nil")
		c, reason = TradeRules.tradable(b, 7)
		expect(`{c} {reason}`).toBe("nil fav")
		c, reason = TradeRules.tradable(b, 99)
		expect(`{c} {reason}`).toBe("nil missing")
		expect(select(2, TradeRules.tradable(profileA(), 5))).toBe("missing") -- someone else's id
	end)

	it("counts 3 trades per UTC day, undone ones included, and rolls over at midnight", function()
		local p = profileA()
		expect(TradeRules.tradesToday(p, DAY)).toBe(0)
		expect(TradeRules.canTrade(p, DAY)).toBe(true)
		p.tradesToday = { day = DAY, count = 2 }
		expect(TradeRules.canTrade(p, DAY)).toBe(true)
		p.tradesToday.count = 3
		expect(TradeRules.canTrade(p, DAY)).toBe(false)
		expect(TradeRules.tradesToday(p, DAY + 1)).toBe(0)
		expect(TradeRules.canTrade(p, DAY + 1)).toBe(true)
		expect(TradeRules.canTrade(p, MetaRules.dayOf((DAY + 1) * 86400 - 1))).toBe(false)
	end)

	it("canCommit re-checks both picks, fairness and the limit on the current profiles", function()
		local t = committing()
		local a, b = profileA(), profileB()
		expect(TradeRules.canCommit(a, b, t, DAY)).toBe(true)
		local released = GardenRules.release(a, 1)
		local ok, reason, who = TradeRules.canCommit(released, b, t, DAY)
		expect(`{ok} {reason} {who}`).toBe("false missing 1")
		ok, reason, who = TradeRules.canCommit(a, GardenRules.favourite(b, 5, NOW), t, DAY)
		expect(`{ok} {reason} {who}`).toBe("false fav 2")
		local rich = GardenRules.copy(a)
		rich.creatures[1].c = "stormy" -- 162 against 45: A gives the more valuable one
		ok, reason, who = TradeRules.canCommit(rich, b, t, DAY)
		expect(`{ok} {reason} {who}`).toBe("false unfair 1")
		local richB = GardenRules.copy(b)
		richB.creatures[1].z = "huge" -- 112.5 against 54
		ok, reason, who = TradeRules.canCommit(a, richB, t, DAY)
		expect(`{ok} {reason} {who}`).toBe("false unfair 2")
		local spent = GardenRules.copy(a)
		spent.tradesToday = { day = DAY, count = 3 }
		ok, reason, who = TradeRules.canCommit(spent, b, t, DAY)
		expect(`{ok} {reason} {who}`).toBe("false limit 1")
		expect(TradeRules.canCommit(spent, b, t, DAY + 1)).toBe(true)
		local spentB = GardenRules.copy(b)
		spentB.tradesToday = { day = DAY, count = 3 }
		ok, reason, who = TradeRules.canCommit(a, spentB, t, DAY)
		expect(`{ok} {reason} {who}`).toBe("false limit 2")
		local unpicked = TradeRules.new(A, B, NOW)
		ok, reason, who = TradeRules.canCommit(a, b, unpicked, DAY)
		expect(`{ok} {reason} {who}`).toBe("false missing 1")
	end)

	it("writes the ledger from the two current picks", function()
		local L = ledger()
		expect(`{L.id} {L.at} {L.a} {L.b} {L.ca.id} {L.ca.s} {L.ca.n} {L.cb.id} {L.cb.s} {L.cb.n}`).toBe(
			`{ID} {NOW + 20} {A} {B} 1 cat Sprinkles 5 hedgehog Pebble`
		)
		expect(L.undoAt).toBeNil()
		expect(L.void).toBeNil()
		expect(same(L.ca, profileA().creatures[1])).toBe(true)
		expect(L.ca ~= profileA().creatures[1]).toBe(true) -- a copy
	end)
end)

describe("TradeRules.give (V1.4, V1.6)", function()
	it("swaps the creatures into each other's slot with fresh ids and names kept, touching nothing else", function()
		local L = ledger()
		local a = TradeRules.give(profileA(), A, L, DAY)
		local b = TradeRules.give(profileB(), B, L, DAY)
		expect(GardenRules.find(a, 1)).toBeNil()
		local got = GardenRules.find(a, 4) :: Creature
		expect(`{got.s} {got.m} {got.z} {got.c} {got.placed} {got.fav} {got.fa} {got.n}`).toBe(
			"hedgehog normal normal none 1 false 0 Pebble"
		)
		expect(a.nextId).toBe(5)
		expect(#a.creatures).toBe(3)
		expect(GardenRules.find(b, 5)).toBeNil()
		local gotB = GardenRules.find(b, 8) :: Creature
		expect(`{gotB.s} {gotB.m} {gotB.z} {gotB.placed} {gotB.n}`).toBe("cat golden big 3 Sprinkles")
		expect(b.nextId).toBe(9)
		local r = a.trades[1]
		expect(`{r.id} {r.at} {r.with} {r.gave.s} {r.got.s} {r.gotId} {r.undone}`).toBe(
			`{ID} {NOW + 20} {B} cat hedgehog 4 false`
		)
		expect(`{b.trades[1].with} {b.trades[1].gave.s} {b.trades[1].got.s} {b.trades[1].gotId}`).toBe(
			`{A} hedgehog cat 8`
		)
		expect(same(a.tradesToday, { day = DAY, count = 1 })).toBe(true)
		expect(same(b.tradesToday, { day = DAY, count = 1 })).toBe(true)
		-- No Index entry, XP, coins, hatch count or quest stat on either side.
		for _, pair in { { a, profileA() }, { b, profileB() } } do
			local after, before = pair[1], pair[2]
			expect(table.concat(after.index, " ")).toBe(table.concat(before.index, " "))
			expect(after.xp).toBe(before.xp)
			expect(after.coins).toBe(before.coins)
			expect(after.hatches).toBe(before.hatches)
			expect(same(after.quests, before.quests)).toBe(true)
			expect(same(after.pity, before.pity)).toBe(true)
			expect(same(after.beds, before.beds)).toBe(true)
		end
		expect(#profileA().trades).toBe(0)
		expect(GardenRules.income(a) > 0).toBe(true)
		expect(same(GardenProgress.sanitize(a, NOW), a)).toBe(true) -- what give writes is what sanitize keeps
	end)

	it("is idempotent on the trade id: applied twice equals once, and a stale re-apply changes nothing", function()
		local L = ledger()
		local once = TradeRules.give(profileA(), A, L, DAY)
		local twice = TradeRules.give(once, A, L, DAY)
		expect(twice).toBe(once)
		expect(same(twice, once)).toBe(true)
		expect(twice.tradesToday.count).toBe(1)
		-- The retried flush starts from the stored (already swapped) record under a later today.
		expect(TradeRules.give(once, A, L, DAY + 1)).toBe(once)
	end)

	it("refuses when the given creature is gone, changed, favourited, or the user is not in the trade", function()
		local L = ledger()
		local a = profileA()
		expect(TradeRules.give(GardenRules.release(a, 1), A, L, DAY).trades[1]).toBeNil()
		local fav = GardenRules.favourite(a, 1, NOW)
		expect(TradeRules.give(fav, A, L, DAY)).toBe(fav)
		local changed = GardenRules.copy(a)
		changed.creatures[1].z = "huge"
		expect(TradeRules.give(changed, A, L, DAY)).toBe(changed)
		changed = GardenRules.copy(a)
		changed.creatures[1].c = "frosted"
		expect(TradeRules.give(changed, A, L, DAY)).toBe(changed)
		changed = GardenRules.copy(a)
		changed.creatures[1].m = "normal"
		expect(TradeRules.give(changed, A, L, DAY)).toBe(changed)
		expect(TradeRules.give(a, 3, L, DAY)).toBe(a)
		-- A new name or a move does not block it: identity is species, mutation, size, charm and id.
		local renamed = GardenRules.setName(GardenRules.store(a, 1), 1, "Zed")
		local out = TradeRules.give(renamed, A, L, DAY)
		expect((GardenRules.find(out, 4) :: Creature).placed).toBe(0) -- the storage slot the cat had
		expect(GardenRules.freePad(out)).toBe(1)
	end)

	it("keeps a stored creature's slot in storage, so a full garden never blocks a trade", function()
		local a = profileA()
		for i = 4, 7 do
			table.insert(a.creatures, creature(i, "bunny", "normal", "normal", i - 1))
		end
		for i = 8, 67 do
			table.insert(a.creatures, creature(i, "bunny", "normal", "normal", 0))
		end
		a.nextId = 68
		expect(GardenRules.isFull(a)).toBe(true)
		local t = committing()
		t.a.pick = 3 -- the stored frog (2)
		local b = profileB()
		table.insert(b.creatures, creature(9, "duck", "normal", "normal", 4)) -- a duck (3): fair
		b.nextId = 10
		t.b.pick = 9
		expect(TradeRules.canCommit(a, b, t, DAY)).toBe(true)
		local L = TradeRules.ledger(t, a, b, ID, NOW)
		local out = TradeRules.give(a, A, L, DAY)
		expect(#out.creatures).toBe(67)
		expect(GardenRules.isFull(out)).toBe(true)
		expect((GardenRules.find(out, 68) :: Creature).s).toBe("duck")
		expect((GardenRules.find(out, 68) :: Creature).placed).toBe(0)
		local outB = TradeRules.give(b, B, L, DAY)
		expect((GardenRules.find(outB, 10) :: Creature).placed).toBe(4)
	end)

	it("caps trades at 30, dropping the oldest, and counts the day with rollover", function()
		local a, b = profileA(), profileB()
		local pa, pb = a, b
		local day = DAY
		for i = 1, 33 do
			-- Each round trades the creature received last time back again.
			local t = TradeRules.new(A, B, NOW)
			t.state = "committing"
			t.a.pick = if i == 1 then 1 else pa.trades[#pa.trades].gotId
			t.b.pick = if i == 1 then 5 else pb.trades[#pb.trades].gotId
			if i % 3 == 1 and i > 1 then
				day += 1
			end
			local L = TradeRules.ledger(t, pa, pb, string.format("%016x", i), NOW + i)
			pa = TradeRules.give(pa, A, L, day)
			pb = TradeRules.give(pb, B, L, day)
			expect(`{i} {#pa.trades}`).toBe(`{i} {math.min(i, 30)}`)
			expect(pa.tradesToday.count).toBe((i - 1) % 3 + 1)
			expect(pa.tradesToday.day).toBe(day)
			expect(TradeRules.canTrade(pa, day)).toBe(i % 3 ~= 0)
		end
		expect(pa.trades[1].id).toBe(string.format("%016x", 4))
		expect(pa.trades[30].id).toBe(string.format("%016x", 33))
		expect(#pa.creatures).toBe(3)
		expect(#pb.creatures).toBe(3)
		expect((GardenRules.find(pa, pa.trades[30].gotId) :: Creature).s).toBe("hedgehog") -- odd rounds give the cat
		expect(same(GardenProgress.sanitize(pa, NOW), pa)).toBe(true)
	end)

	it("never resets today's count when a heal applies an older day's trade", function()
		local L = ledger()
		local a = profileA()
		a.tradesToday = { day = DAY, count = 2 }
		local out = TradeRules.give(a, A, L, DAY - 1)
		expect(same(out.tradesToday, { day = DAY, count = 2 })).toBe(true)
		expect(#out.trades).toBe(1)
	end)
end)

describe("TradeRules undo (V1.5)", function()
	local function traded(): (Profile, Profile, TradeRules.Ledger)
		local L = ledger()
		return TradeRules.give(profileA(), A, L, DAY), TradeRules.give(profileB(), B, L, DAY), L
	end

	it("allows an undo within 10 minutes once, and refuses missing, undone, late or released", function()
		local a, _, L = traded()
		expect(TradeRules.canUndo(a, ID, NOW + 20)).toBe(true)
		expect(TradeRules.canUndo(a, ID, NOW + 20 + 600)).toBe(true)
		local ok, reason = TradeRules.canUndo(a, ID, NOW + 20 + 601)
		expect(`{ok} {reason}`).toBe("false late")
		ok, reason = TradeRules.canUndo(a, "ffffffffffffffff", NOW + 20)
		expect(`{ok} {reason}`).toBe("false missing")
		ok, reason = TradeRules.canUndo(GardenRules.release(a, 4), ID, NOW + 20)
		expect(`{ok} {reason}`).toBe("false released")
		ok, reason = TradeRules.canUndo(TradeRules.undo(a, A, L), ID, NOW + 20)
		expect(`{ok} {reason}`).toBe("false undone")
		-- A favourite lock on the received creature does not block its return.
		expect(TradeRules.canUndo(GardenRules.favourite(a, 4, NOW), ID, NOW + 20)).toBe(true)
	end)

	it("returns the creatures to the slots they now occupy, idempotently, with the record marked", function()
		local a, b, L = traded()
		a = GardenRules.store(a, 4) -- A put the hedgehog in storage meanwhile
		local ua = TradeRules.undo(a, A, L)
		expect(GardenRules.find(ua, 4)).toBeNil()
		local back = GardenRules.find(ua, 5) :: Creature
		expect(`{back.s} {back.m} {back.z} {back.c} {back.placed} {back.n} {back.fav}`).toBe(
			"cat golden big none 0 Sprinkles false"
		)
		expect(ua.trades[1].undone).toBe(true)
		expect(ua.nextId).toBe(6)
		expect(TradeRules.undo(ua, A, L)).toBe(ua)
		expect(a.trades[1].undone).toBe(false) -- input unchanged
		local ub = TradeRules.undo(b, B, L)
		local backB = GardenRules.find(ub, 9) :: Creature
		expect(`{backB.s} {backB.placed} {backB.n}`).toBe("hedgehog 3 Pebble")
		expect(ub.trades[1].undone).toBe(true)
		expect(same(ub.tradesToday, { day = DAY, count = 1 })).toBe(true) -- still counts
		expect(ub.xp).toBe(profileB().xp)
		expect(ub.coins).toBe(profileB().coins)
		expect(same(ub.index, profileB().index)).toBe(true)
		-- The favourite lock A put on the hedgehog goes with it.
		local locked = TradeRules.undo(GardenRules.favourite(a, 4, NOW), A, L)
		expect(GardenRules.find(locked, 4)).toBeNil()
		expect((GardenRules.find(locked, 5) :: Creature).fav).toBe(false)
	end)

	it("refuses when the got creature is gone or the user is not in the trade", function()
		local a, _, L = traded()
		local released = GardenRules.release(a, 4)
		expect(TradeRules.undo(released, A, L)).toBe(released)
		expect(TradeRules.undo(a, 3, L)).toBe(a)
		local fresh = profileA()
		expect(TradeRules.undo(fresh, A, L)).toBe(fresh) -- never traded
	end)

	it("give then undo on both profiles equals the originals except trades, tradesToday and nextId", function()
		local a, b, L = traded()
		local ua, ub = TradeRules.undo(a, A, L), TradeRules.undo(b, B, L)
		for _, pair in { { ua, profileA(), 6, "cat", 1 }, { ub, profileB(), 10, "hedgehog", 5 } } do
			local after, before, nextId = pair[1] :: Profile, pair[2] :: Profile, pair[3] :: number
			expect(after.nextId).toBe(nextId)
			expect(#after.trades).toBe(1)
			expect(after.trades[1].undone).toBe(true)
			expect(same(after.tradesToday, { day = DAY, count = 1 })).toBe(true)
			after = GardenRules.copy(after)
			after.trades, after.tradesToday, after.nextId = before.trades, before.tradesToday, before.nextId
			-- The returned creature has a new id; everything else about it is the original.
			for _, c in after.creatures do
				if c.s == pair[4] then
					c.id = pair[5] :: number
				end
			end
			table.sort(after.creatures, function(x, y)
				return x.id < y.id
			end)
			expect(same(after, before)).toBe(true)
		end
	end)
end)

describe("TradeRules.heal (V1.4 step 4)", function()
	local function always(_: TradeRules.Ledger): boolean
		return true
	end
	local function never(_: TradeRules.Ledger): boolean
		return false
	end

	it("applies a missing give when the counterpart ledger confirms it, and nothing otherwise", function()
		local L = ledger()
		local a = profileA()
		local healed = TradeRules.heal(a, A, { L }, always, NOW + 100)
		expect(same(healed, TradeRules.give(a, A, L, DAY))).toBe(true)
		expect(TradeRules.heal(a, A, { L }, never, NOW + 100)).toBe(a)
		expect(TradeRules.heal(a, A, {}, always, NOW + 100)).toBe(a)
		local asked = 0
		local done = TradeRules.give(a, A, L, DAY)
		expect(TradeRules.heal(done, A, { L }, function()
			asked += 1
			return true
		end, NOW + 100)).toBe(done)
		expect(asked).toBe(0) -- the lookup is only for missing records
	end)

	it("applies a missing undo, skips void records and ignores ones older than the oldest kept", function()
		local L = ledger()
		local a = TradeRules.give(profileA(), A, L, DAY)
		local undone = table.clone(L)
		undone.undoAt = NOW + 60
		local healed = TradeRules.heal(a, A, { undone }, never, NOW + 100)
		expect(same(healed, TradeRules.undo(a, A, L))).toBe(true)
		expect(TradeRules.heal(healed, A, { undone }, never, NOW + 100)).toBe(healed)
		-- Missing give and undo together: both land.
		local both = TradeRules.heal(profileA(), A, { undone }, always, NOW + 100)
		expect(same(both, TradeRules.undo(TradeRules.give(profileA(), A, L, DAY), A, L))).toBe(true)
		-- Void: nothing, even when confirmed.
		local void = table.clone(L)
		void.void = true
		local fresh = profileA()
		expect(TradeRules.heal(fresh, A, { void }, always, NOW + 100)).toBe(fresh)
		-- Oldest kept: a profile with 30 records ignores anything older than its first.
		local full = profileA()
		for i = 1, 30 do
			table.insert(full.trades, {
				id = string.format("%016x", i),
				at = NOW - 1000 + i,
				with = B,
				gave = creature(1, "cat", "golden", "big", 1),
				got = creature(5, "hedgehog", "normal", "normal", 3),
				gotId = 50 + i,
				undone = true,
			})
		end
		local old = table.clone(L)
		old.id, old.at = "00000000000000aa", NOW - 2000
		expect(TradeRules.heal(full, A, { old }, always, NOW)).toBe(full)
		local newer = table.clone(L)
		newer.id, newer.at = "00000000000000bb", NOW - 900
		local kept = TradeRules.heal(full, A, { newer }, always, NOW)
		expect(#kept.trades).toBe(30)
		expect(kept.trades[30].id).toBe("00000000000000bb")
		-- Not at the cap: an old record is still applied, oldest first.
		local two = TradeRules.heal(profileA(), A, { newer, old }, function(x)
			return x.id == "00000000000000aa"
		end, NOW)
		expect(#two.trades).toBe(1)
		expect(two.trades[1].id).toBe("00000000000000aa")
	end)

	-- QA B1: a commit cancelled after both ledger writes voids both copies; when only one void mark
	-- lands, neither heal may complete the trade (it used to give one child a copy of the other's
	-- creature while the other kept it: two Golden Lions and no Dragon).
	it("one copy void: neither heal completes a cancelled trade, whichever mark landed", function()
		local L = ledger()
		local void = table.clone(L)
		void.void = true
		expect(TradeRules.confirms(L)).toBe(true)
		expect(TradeRules.confirms(void)).toBe(false)
		expect(TradeRules.confirms(nil)).toBe(false)
		for _, copies in { { [A] = void, [B] = L }, { [A] = L, [B] = void }, { [A] = void, [B] = void } } do
			local a, b = profileA(), profileB()
			-- Each heal reads its own copy and asks the counterpart's copy, as Trades.heal does.
			local healedA = TradeRules.heal(a, A, { copies[A] }, function(_)
				return TradeRules.confirms(copies[B])
			end, NOW + 100)
			local healedB = TradeRules.heal(b, B, { copies[B] }, function(_)
				return TradeRules.confirms(copies[A])
			end, NOW + 100)
			expect(healedA).toBe(a)
			expect(healedB).toBe(b)
		end
		-- Neither void (every mark lost): both heal to the one commit, still no duplicate (V1.4 residual).
		local healedA = TradeRules.heal(profileA(), A, { L }, function(_)
			return TradeRules.confirms(L)
		end, NOW + 100)
		local healedB = TradeRules.heal(profileB(), B, { L }, function(_)
			return TradeRules.confirms(L)
		end, NOW + 100)
		expect(GardenRules.find(healedA, 1)).toBeNil()
		expect(GardenRules.find(healedB, 5)).toBeNil()
		expect(healedA.creatures[1].s .. " " .. healedB.creatures[1].s).toBe("hedgehog cat")
	end)

	it("heals the half that a crash left out so both profiles end up as one commit would", function()
		local L = ledger()
		local a = TradeRules.give(profileA(), A, L, DAY) -- A flushed
		local b = profileB() -- B's flush was lost
		local healedB = TradeRules.heal(b, B, { L }, always, NOW + 3600)
		expect(same(healedB, TradeRules.give(profileB(), B, L, DAY))).toBe(true)
		expect(TradeRules.heal(a, A, { L }, always, NOW + 3600)).toBe(a)
		expect(healedB.tradesToday.day).toBe(MetaRules.dayOf(L.at))
	end)
end)

describe("TradeRules.status", function()
	it("builds the trade Fx payload with each side's pick as the server sees it", function()
		local t = committing()
		local a = profileA()
		local s = TradeRules.status(t, { [A] = "Ann", [B] = "Ben" }, { [A] = GardenRules.find(a, 1), [B] = nil })
		expect(`{s.state} {s.id} {s.reason} {s.at}`).toBe("committing nil nil 0")
		expect(`{s.a.user} {s.a.name} {s.a.ready} {s.a.confirmed}`).toBe(`{A} Ann true true`)
		expect(`{s.a.pick.id} {s.a.pick.s} {s.a.pick.m} {s.a.pick.z} {s.a.pick.c} {s.a.pick.n} {s.a.pick.rate}`).toBe(
			"1 cat golden big none Sprinkles 54"
		)
		expect(`{s.b.user} {s.b.name} {s.b.pick}`).toBe(`{B} Ben nil`)
		local c = TradeRules.step(picked(), B, "cancel", nil, NOW)
		c.id = ID
		local sc = TradeRules.status(c, {}, {})
		expect(`{sc.state} {sc.id} {sc.reason} {sc.a.name} {sc.a.pick}`).toBe(`cancelled {ID} cancelled nil nil`)
	end)
end)
