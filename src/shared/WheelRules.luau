--!strict
-- Pure Petal Catch rules (docs/game-design/game4-wheel.md W3 to W6, docs/architecture/garden-wheel.md
-- 2.2, decision 0016): the seeded drop schedule the server and every client compute alike, the
-- server's catch check on each 5 Hz root sample, tiers, the wheel roll and the idempotent prize op.
-- Times are floats from the server's GetServerTimeNow. Functions return new tables and never mutate
-- their inputs. No Roblox APIs.

local GardenConfig = require("./GardenConfig")
local GardenProgress = require("./GardenProgress")
local Rng = require("./Rng")

local WheelRules = {}

export type Vec3 = { x: number, y: number, z: number }
export type Kind = "pink" | "gold" | "cone"
export type Tier = "none" | "spin" | "lucky"
export type Drop = { at: number, kind: Kind, x: number, z: number } -- at: server time it leaves the canopy
export type Round = {
	id: number, -- UserId
	seed: number,
	startAt: number,
	endAt: number,
	eligible: boolean, -- saving session and under the cap at the start
	n: number, -- the spin this round can earn: spinsToday + 1 (meaningless when not eligible)
	score: number,
	done: { [number]: boolean }, -- drop index -> resolved (caught or landed)
}
export type Event = {
	kind: string, -- "catch" | "over"
	i: number?, -- catch: drop index
	drop: Kind?, -- catch
	score: number?, -- catch: after; over: final
	tier: Tier?, -- over
}

type Profile = GardenConfig.Profile

local WHEEL = GardenConfig.WHEEL
local TOTAL = WHEEL.drops.pink + WHEEL.drops.gold + WHEEL.drops.cone

-- Exactly the 2.2 algorithm: a fixed composition shuffled by seed, then two draws per drop for a
-- ring spot. Any drift between server and client here is a scoring bug.
function WheelRules.schedule(seed: number, startAt: number): { Drop }
	local list: { Kind } = {}
	for _, pair in { { "pink", WHEEL.drops.pink }, { "gold", WHEEL.drops.gold }, { "cone", WHEEL.drops.cone } } do
		for _ = 1, pair[2] :: number do
			table.insert(list, pair[1] :: Kind)
		end
	end
	local state: Rng.State = seed
	for i = TOTAL, 2, -1 do
		local j
		j, state = Rng.int(state, 1, i)
		list[i], list[j] = list[j], list[i]
	end
	local drops: { Drop } = {}
	for i = 1, TOTAL do
		local u, v
		u, state = Rng.next(state)
		v, state = Rng.next(state)
		local r = WHEEL.ring.min + (WHEEL.ring.max - WHEEL.ring.min) * math.sqrt(u)
		local a = 2 * math.pi * v
		drops[i] = {
			at = startAt + WHEEL.lead + (i - 1) * WHEEL.gap,
			kind = list[i],
			x = WHEEL.centre.x + r * math.cos(a),
			z = WHEEL.centre.z + r * math.sin(a),
		}
	end
	return drops
end

function WheelRules.new(id: number, seed: number, t: number, eligible: boolean, n: number): Round
	return {
		id = id,
		seed = seed,
		startAt = t,
		endAt = t + WHEEL.round,
		eligible = eligible,
		n = n,
		score = 0,
		done = {},
	}
end

-- (from, to): the server times the drop is catchable.
function WheelRules.bandAt(drop: Drop): (number, number)
	return drop.at + (WHEEL.canopy - WHEEL.band.top) / WHEEL.fall,
		drop.at + (WHEEL.canopy - WHEEL.band.bottom) / WHEEL.fall
end

-- One 5 Hz sample. A drop past its band is done without an event; one inside it within catchRadius
-- of the root (and the root near the ground) is caught. No-op after endAt.
function WheelRules.sample(r: Round, drops: { Drop }, pos: Vec3, t: number): (Round, { Event })
	if t >= r.endAt then
		return r, {}
	end
	local out: Round? = nil
	local events: { Event } = {}
	local radius = WHEEL.catchRadius
	local nearGround = pos.y >= WHEEL.centre.y - 2 and pos.y <= WHEEL.centre.y + 10
	for i, d in drops do
		if r.done[i] then
			continue
		end
		local from, to = WheelRules.bandAt(d)
		local landed = t > to
		local dx, dz = pos.x - d.x, pos.z - d.z
		local caught = not landed and t >= from and nearGround and dx * dx + dz * dz <= radius * radius
		if landed or caught then
			if out == nil then
				out = table.clone(r)
				out.done = table.clone(r.done)
			end
			local o = out :: Round
			o.done[i] = true
			if caught then
				o.score = math.max(0, o.score + WHEEL.points[d.kind])
				table.insert(events, { kind = "catch", i = i, drop = d.kind, score = o.score })
			end
		end
	end
	return out or r, events
end

function WheelRules.tier(r: Round): Tier
	if not r.eligible or r.score < WHEEL.spinAt then
		return "none"
	end
	return if r.score >= WHEEL.luckyAt then "lucky" else "spin"
end

function WheelRules.finish(r: Round, t: number): (Round, { Event })
	if t < r.endAt then
		return r, {}
	end
	return r, { { kind = "over", score = r.score, tier = WheelRules.tier(r) } }
end

-- Wedge id by one draw over the chosen column.
function WheelRules.roll(state: Rng.State, lucky: boolean): (string, Rng.State)
	local n, next = Rng.int(state, 1, 10000)
	local acc = 0
	for _, w in WHEEL.wedges do
		acc += if lucky then w.lucky else w.standard
		if n <= acc then
			return w.id, next
		end
	end
	return WHEEL.wedges[#WHEEL.wedges].id, next
end

function WheelRules.spinsToday(p: Profile, today: number): number
	return if p.wheelToday.day == today then p.wheelToday.spins else 0
end

function WheelRules.spinsLeft(p: Profile, today: number): number
	return WHEEL.spinsPerDay - WheelRules.spinsToday(p, today)
end

function WheelRules.canSpin(p: Profile, today: number): boolean
	return WheelRules.spinsLeft(p, today) > 0
end

function WheelRules.spinId(today: number, n: number): number
	return today * 10 + n
end

-- The prize op, idempotent on (today, n): a re-apply, an out-of-order op and the cap all return the
-- profile unchanged. (profile, applied, coins paid).
function WheelRules.award(p: Profile, today: number, n: number, wedge: string): (Profile, boolean, number)
	if WheelRules.spinsToday(p, today) ~= n - 1 or n > WHEEL.spinsPerDay then
		return p, false, 0
	end
	local out = table.clone(p)
	out.wheelToday = { day = today, spins = n }
	local paid = 0
	if wedge == "coins" then
		paid = math.min(GardenConfig.MAX_COINS - p.coins, GardenProgress.scaled(p, WHEEL.coinsBase, WHEEL.coinsMinutes))
		out.coins = p.coins + paid
	else
		out.prizeEggs = table.clone(p.prizeEggs)
		out.prizeEggs[wedge] = math.min(GardenConfig.PRIZE_STORE, (p.prizeEggs[wedge] or 0) + 1)
	end
	return out, true, paid
end

return WheelRules
