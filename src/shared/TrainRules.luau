--!strict
-- Lantern Express run state machine (architecture lantern 3.7, GDD B to F, I, J; decision 0018
-- section 2). The server samples the world at 10 Hz into an Input (who sits where, standing
-- depths at a stop, who is in the load box, fresh turret beams, lantern points) and calls `tick`;
-- everything else is time. `tick` returns the new run and the events the server acts on (seat or
-- stand a player, build or clear a stop, pay a load, play an effect). Times are GetServerTimeNow
-- floats. Functions return new tables and never mutate their inputs. No Roblox APIs.
--
-- Payouts are events, never state: "load" (items, n) pays each active member's own save at once;
-- "depot", "dawn" (payload.fed: pay the Lampeater's +50 too) and "end" (payload.parts: each
-- member's leftover Parts share) pay every member aboard; "stopLeft" pays the stop XP. "fed" is
-- display only. Nothing a run takes away (coal, Parts, oil, the lantern, upgrades, carried items)
-- was ever written to a save.

local CarryRules = require("./CarryRules")
local DepotRules = require("./DepotRules")
local LanternConfig = require("./LanternConfig")
local LootRules = require("./LootRules")
local MetaRules = require("./MetaRules")
local Rng = require("./Rng")
local WispRules = require("./WispRules")

local TrainRules = {}

type SeatKind = LanternConfig.SeatKind
type Vec3 = LanternConfig.Vec3
export type Phase = "hub" | "ride" | "stop" | "night" | "depot" | "ended"
export type Member = {
	userId: number,
	joined: number,
	active: number,
	seat: SeatKind?, -- where the member sits now (from Input.seats, or where the server was told to seat them)
	lastSeat: SeatKind?,
	-- End of the fog limbo. 0 once back on the train: "caught at this stop" until the train leaves.
	limboUntil: number?,
	stokeAt: number,
	mendAt: number,
}
export type Run = {
	phase: Phase,
	phaseAt: number,
	seed: number,
	weekly: boolean,
	leg: number,
	stop: number,
	line: LanternConfig.Line,
	track: string,
	d: number,
	speed: number,
	target: number,
	stokeUntil: number,
	coal: number,
	lantern: number,
	oil: number,
	parts: number,
	levels: DepotRules.Levels,
	pourAt: number,
	bellAt: number?,
	allSeatedAt: number?,
	firstSitAt: number?,
	crew: { [number]: Member },
	order: { number },
	votes: { [number]: string },
	loot: LootRules.Stop?,
	carries: CarryRules.Carries,
	night: WispRules.Night?,
	critters: number,
	dist: number,
	fed: boolean,
	ended: ("dawn" | "coal" | "lantern" | "empty")?,
}
export type Input = {
	now: number,
	dt: number,
	seats: { [number]: SeatKind? }, -- the seat kind each crew member sits in now (Seat.Occupant)
	depth: { [number]: number? }, -- stop frame depth of each standing crew member during a stop
	loadBox: { [number]: boolean }, -- crew member's root inside the train's load box
	beams: { WispRules.Beam }, -- turret beams in the train frame (fresh aims only)
	lanterns: { Vec3 }, -- lantern points in the train frame
}
export type Event = {
	kind: string,
	userId: number?,
	items: { LootRules.Item }?,
	n: number?,
	reason: string?,
	payload: any?,
}

local C = LanternConfig
local STOP, HUB, DEPOT, LANTERN, STOKE = C.STOP, C.HUB, C.DEPOT, C.LANTERN, C.STOKE
local FOG_RAMP = (STOP.fogMax - STOP.fogV0) / STOP.fogAcc
local RAMP_DIST = STOP.fogV0 * FOG_RAMP + STOP.fogAcc * FOG_RAMP * FOG_RAMP / 2
TrainRules.FOG_TIME = FOG_RAMP + (STOP.depth - RAMP_DIST) / STOP.fogMax -- 13.125 s from the bell to the platform
TrainRules.MAX_DIST = 3 * 5700 -- the Farthest board's cap: three legs (architecture 11.9)

local PREFER: { [string]: { SeatKind } } = {
	hub = { "stoker", "turret", "mender", "passenger" }, -- GDD I4: the Stoker seat first
	ride = { "passenger", "turret", "stoker", "mender" },
	night = { "turret", "mender", "stoker", "passenger" }, -- GDD E1: turrets first
}

-- Helpers ----------------------------------------------------------------------------------------

local function copy(run: Run): Run
	local out = table.clone(run)
	out.levels = table.clone(run.levels)
	out.crew = {}
	for userId, m in run.crew do
		out.crew[userId] = table.clone(m)
	end
	out.order = table.clone(run.order)
	out.votes = table.clone(run.votes)
	return out
end

local function inLimbo(m: Member, now: number): boolean
	return m.limboUntil ~= nil and now < m.limboUntil
end

local function track(run: Run): LanternConfig.Track
	return C.TRACKS[run.track]
end

local function pickSeat(run: Run, prefer: { SeatKind }, last: SeatKind?): SeatKind?
	local used: { [string]: number } = {}
	for _, m in run.crew do
		if m.seat then
			used[m.seat] = (used[m.seat] or 0) + 1
		end
	end
	for i = 0, #prefer do
		local kind = if i == 0 then last else prefer[i]
		if kind and (used[kind] or 0) < C.SEAT_COUNTS[kind] then
			return kind
		end
	end
	return nil
end

-- Seats every member who stands and is not in the fog (their last kind first): "seat" events.
local function seatAll(out: Run, now: number, prefer: { SeatKind }, events: { Event })
	for _, userId in out.order do
		local m = out.crew[userId]
		if m.seat == nil and not inLimbo(m, now) then
			local kind = pickSeat(out, prefer, m.lastSeat)
			if kind then
				m.seat, m.lastSeat = kind, kind
				table.insert(events, { kind = "seat", userId = userId, payload = kind })
			end
		end
	end
end

local function standAll(out: Run, events: { Event })
	for _, userId in out.order do
		local m = out.crew[userId]
		if m.seat then
			m.lastSeat, m.seat = m.seat, nil
		end
		table.insert(events, { kind = "unseat", userId = userId })
	end
end

-- Everyone not in the fog sits; a crew member in limbo does not hold the train (architecture 11.5).
local function allSeated(out: Run, now: number): boolean
	for _, m in out.crew do
		if m.seat == nil and not inLimbo(m, now) then
			return false
		end
	end
	return true
end

local function fogTravel(t: number): number
	local ramp = math.clamp(t, 0, FOG_RAMP)
	return STOP.fogV0 * ramp + STOP.fogAcc * ramp * ramp / 2 + STOP.fogMax * math.max(0, t - FOG_RAMP)
end

local function finishRun(out: Run, now: number, reason: "dawn" | "coal" | "lantern" | "empty", events: { Event })
	if out.loot then
		out.loot = CarryRules.close(out.loot, out.carries)
	end
	out.phase, out.phaseAt, out.ended = "ended", now, reason
	out.speed, out.stokeUntil, out.night, out.loot, out.carries = 0, 0, nil, nil, {}
	out.bellAt, out.allSeatedAt = nil, nil
	if reason == "dawn" then
		out.dist = TrainRules.MAX_DIST
	end
	standAll(out, events)
	table.insert(events, {
		kind = "end",
		reason = reason,
		payload = {
			parts = DepotRules.leftover(out.parts, #out.order),
			critters = out.critters,
			dist = math.floor(out.dist),
		},
	})
end

-- Leaves the hub, a stop or the Depot. `next` is the phase the train moves in.
local function depart(out: Run, now: number, events: { Event })
	out.phaseAt, out.speed, out.bellAt, out.allSeatedAt, out.firstSitAt = now, 0, nil, nil, nil
	local t = track(out)
	if out.stop > #t.stops then
		out.phase, out.target = "night", t.finish
		out.night = WispRules.new(now, out.seed, out.leg)
		table.insert(events, { kind = "night" })
	else
		out.phase, out.target = "ride", t.stops[out.stop]
	end
	table.insert(events, { kind = "depart", payload = out.track })
end

local function arrive(out: Run, now: number, events: { Event })
	out.speed, out.stokeUntil, out.phaseAt, out.allSeatedAt = 0, 0, now, nil
	if out.phase == "ride" then
		out.phase, out.bellAt = "stop", nil
		standAll(out, events)
		table.insert(events, { kind = "arrive", n = out.stop })
		if out.stop == #track(out).stops and out.coal < TrainRules.coalNeed(out) then
			table.insert(events, { kind = "coalLow", reason = "night" }) -- the last stop before tonight
		end
		return
	end
	out.night = nil
	if out.leg >= 3 then
		table.insert(events, { kind = "dawn", payload = { fed = out.fed } })
		finishRun(out, now, "dawn", events)
		return
	end
	out.phase = "depot"
	out.lantern = math.min(LANTERN.max, out.lantern + LANTERN.depot)
	out.votes = {}
	standAll(out, events)
	table.insert(events, { kind = "depot", n = out.leg })
end

-- Public API -------------------------------------------------------------------------------------

function TrainRules.new(seed: number, now: number): Run
	return {
		phase = "hub",
		phaseAt = now,
		seed = seed,
		weekly = false,
		leg = 1,
		stop = 1,
		line = "forest",
		track = "forest",
		d = 0,
		speed = 0,
		target = C.TRACKS.forest.stops[1],
		stokeUntil = 0,
		coal = C.BUNKER[1],
		lantern = LANTERN.max,
		oil = 0,
		parts = 0,
		levels = { boiler = 1, bunker = 1, lamps = 1 },
		pourAt = -math.huge,
		bellAt = nil,
		allSeatedAt = nil,
		firstSitAt = nil,
		crew = {},
		order = {},
		votes = {},
		loot = nil,
		carries = {},
		night = nil,
		critters = 0,
		dist = 0,
		fed = false,
		ended = nil,
	}
end

local PLACEMENT = { hub = "seat", ride = "seat", night = "seat", stop = "platform", depot = "depot", ended = "hub" }

-- GDD I4. "seat": seat the player in run.crew[userId].seat. A full crew changes nothing ("hub").
function TrainRules.join(run: Run, userId: number, now: number): (Run, "seat" | "platform" | "depot" | "hub")
	local placement = PLACEMENT[run.phase] :: any
	if run.crew[userId] then
		return run, placement
	elseif #run.order >= C.CREW.max then
		return run, "hub"
	end
	local out = copy(run)
	local m: Member = {
		userId = userId,
		joined = now,
		active = now,
		seat = nil,
		lastSeat = nil,
		limboUntil = nil,
		stokeAt = -math.huge,
		mendAt = -math.huge,
	}
	if placement == "seat" then
		m.seat = pickSeat(out, PREFER[run.phase])
		m.lastSeat = m.seat
	end
	out.crew[userId] = m
	table.insert(out.order, userId)
	return out, placement
end

-- Drops what the member carries (or lets go of a crate), removes their vote; the last member out
-- ends the run ("empty"; the next tick returns to the hub at once).
function TrainRules.leave(run: Run, userId: number, at: Vec3?): (Run, { Event })
	if run.crew[userId] == nil then
		return run, {}
	end
	local out = copy(run)
	local events: { Event } = {}
	if out.loot then
		out.loot, out.carries = CarryRules.drop(out.loot, out.carries, userId, at or { x = 0, y = 0, z = 0 })
	end
	out.crew[userId], out.votes[userId] = nil, nil
	table.remove(out.order, table.find(out.order, userId) :: number)
	if #out.order == 0 and out.phase ~= "hub" and out.phase ~= "ended" then
		finishRun(out, -math.huge, "empty", events)
	end
	return out, events
end

function TrainRules.touch(run: Run, userId: number, now: number): Run
	local m = run.crew[userId]
	if m == nil then
		return run
	end
	local out = table.clone(run)
	out.crew = table.clone(run.crew)
	local changed = table.clone(m)
	changed.active = now
	out.crew[userId] = changed
	return out
end

function TrainRules.activeCount(run: Run, now: number): number
	local n = 0
	for _, m in run.crew do
		if now - m.active <= C.CREW.active then
			n += 1
		end
	end
	return if #run.order > 0 then math.max(1, n) else 0
end

function TrainRules.fogFront(run: Run, now: number): number?
	if run.phase ~= "stop" or run.bellAt == nil then
		return nil
	end
	return math.max(0, STOP.depth - fogTravel(now - run.bellAt))
end

function TrainRules.coalNeed(run: Run): number
	if run.phase == "ended" then
		return 0
	end
	return math.max(0, track(run).finish - run.d) * C.COAL_PER_STUD
end

function TrainRules.conductor(run: Run): number?
	return run.order[1]
end

-- The time the train leaves if nothing changes (0 while it moves).
local function leaveAt(run: Run): number
	local seated = run.allSeatedAt
	if run.phase == "hub" then
		local t = math.min(
			if seated then seated + HUB.grace else math.huge,
			if run.firstSitAt then run.firstSitAt + HUB.firstSit else math.huge
		)
		return if t == math.huge then 0 else t
	elseif run.phase == "stop" then
		local fog = (run.bellAt or run.phaseAt + STOP.calm) + TrainRules.FOG_TIME
		return if seated then math.min(fog, math.max(seated + STOP.grace, run.phaseAt + STOP.minStay)) else fog
	elseif run.phase == "depot" then
		local cap = run.phaseAt + DEPOT.max
		return if seated then math.min(cap, math.max(seated + DEPOT.grace, run.phaseAt + DEPOT.minStay)) else cap
	elseif run.phase == "ended" then
		return run.phaseAt + C.END_CARD
	end
	return 0
end

-- The LanternRun attributes of decision 0018 section 3 (Crew and Votes are tables to JSON-encode).
function TrainRules.status(run: Run, now: number): { [string]: any }
	local crew = {}
	for _, userId in run.order do
		local m = run.crew[userId]
		table.insert(crew, { userId = userId, seat = m.seat or "", active = now - m.active <= C.CREW.active })
	end
	local votes: { [string]: number } = {}
	for _, choice in run.votes do
		votes[choice] = (votes[choice] or 0) + 1
	end
	return {
		Phase = run.phase,
		Leg = run.leg,
		Stop = run.stop,
		Line = run.line,
		Weekly = run.weekly,
		Tile = if run.loot then run.loot.tile else "",
		PhaseAt = run.phaseAt,
		BellAt = run.bellAt or 0,
		LeaveAt = leaveAt(run),
		D = run.d,
		Speed = run.speed,
		Coal = run.coal,
		CoalCap = DepotRules.bunker(run.levels),
		CoalNeed = TrainRules.coalNeed(run),
		Lantern = run.lantern,
		Oil = run.oil,
		Parts = run.parts,
		Boiler = run.levels.boiler,
		Bunker = run.levels.bunker,
		Lamps = run.levels.lamps,
		Wave = if run.night then run.night.wave else 0,
		Conductor = run.order[1] or 0,
		Crew = crew,
		Votes = votes,
	}
end

-- The tick ---------------------------------------------------------------------------------------

local function load(out: Run, input: Input, events: { Event })
	local loot = out.loot :: LootRules.Stop
	for _, userId in out.order do
		if input.loadBox[userId] and out.carries[userId] then
			local items
			loot, out.carries, items =
				CarryRules.load(loot, out.carries, userId, DepotRules.bunker(out.levels) - out.coal)
			if #items > 0 then
				for _, item in items do
					local spec = C.ITEMS[item.kind]
					if item.kind == "coal" then
						out.coal = math.min(DepotRules.bunker(out.levels), out.coal + (spec.coal :: number))
					elseif item.kind == "oil" and out.oil >= LANTERN.store then
						out.lantern = math.min(LANTERN.max, out.lantern + LANTERN.autoPour) -- GDD C1: pours at once
					elseif item.kind == "oil" then
						out.oil += spec.oil :: number
					elseif item.kind == "critter" then
						out.critters += 1
					else
						out.parts += spec.parts :: number
					end
				end
				out.crew[userId].active = input.now
				table.insert(
					events,
					{ kind = "load", userId = userId, items = items, n = TrainRules.activeCount(out, input.now) }
				)
			end
		end
	end
	out.loot = loot
end

local function stopTick(out: Run, input: Input, events: { Event })
	local now = input.now
	if out.bellAt == nil and now >= out.phaseAt + STOP.calm then
		out.bellAt = out.phaseAt + STOP.calm
		table.insert(events, { kind = "bell" })
	end
	if out.loot then
		load(out, input, events)
	end
	local front = TrainRules.fogFront(out, now)
	if front then
		for _, userId in out.order do
			local m, depth = out.crew[userId], input.depth[userId]
			if depth and depth > front and m.seat == nil and not inLimbo(m, now) then
				if out.loot then
					out.loot, out.carries = CarryRules.catch(out.loot, out.carries, userId, { x = 0, y = 0, z = depth })
				end
				m.limboUntil = now + STOP.limbo
				table.insert(events, { kind = "caught", userId = userId })
			end
		end
	end
	local seated = allSeated(out, now)
	out.allSeatedAt = if seated then out.allSeatedAt or now else nil
	local early = seated
		and now >= (out.allSeatedAt :: number) + STOP.grace - 1e-9
		and now >= out.phaseAt + STOP.minStay - 1e-9
	if not early and not (front ~= nil and front <= 0) then
		return
	end
	seatAll(out, now, if out.stop >= #track(out).stops then PREFER.night else PREFER.ride, events)
	if out.loot then
		out.loot, out.carries = CarryRules.close(out.loot, out.carries)
	end
	for _, userId in out.order do
		local m = out.crew[userId]
		if m.limboUntil == nil then
			table.insert(events, { kind = "stopLeft", userId = userId })
		elseif not inLimbo(m, now) then
			m.limboUntil = nil
		end
	end
	out.loot, out.carries = nil, {}
	out.stop += 1
	depart(out, now, events)
end

local function waitTick(out: Run, now: number, events: { Event })
	local seated = #out.order > 0 and allSeated(out, now)
	out.allSeatedAt = if seated then out.allSeatedAt or now else nil
	local go = false
	if out.phase == "hub" then
		local anySeated = false
		for _, m in out.crew do
			anySeated = anySeated or m.seat ~= nil
		end
		out.firstSitAt = if anySeated then out.firstSitAt or now else nil
		go = (seated and now >= (out.allSeatedAt :: number) + HUB.grace - 1e-9)
			or (out.firstSitAt ~= nil and now >= out.firstSitAt + HUB.firstSit - 1e-9)
	else
		go = (
			seated
			and now >= (out.allSeatedAt :: number) + DEPOT.grace - 1e-9
			and now >= out.phaseAt + DEPOT.minStay - 1e-9
		) or now >= out.phaseAt + DEPOT.max - 1e-9
	end
	if not go then
		return
	end
	if out.phase == "hub" then
		if DepotRules.tally(out.votes, { "free", "weekly" }, "free") == "weekly" then
			out.weekly = true
			out.seed = Rng.seed(MetaRules.weekOf(MetaRules.dayOf(now)), C.WEEKLY_SALT)
		end
		seatAll(out, now, PREFER.hub, events)
	else
		out.line = DepotRules.tally(out.votes, { "forest", "lake" }, "forest") :: LanternConfig.Line
		out.leg += 1
		out.track = if out.leg >= 3 then out.line .. "Dawn" else out.line
		out.stop, out.d = 1, 0
		seatAll(out, now, PREFER.ride, events)
	end
	out.votes = {}
	depart(out, now, events)
end

local function moveTick(out: Run, input: Input, events: { Event })
	local now, dt = input.now, input.dt
	seatAll(out, now, PREFER[out.phase], events) -- the seated rule: nobody stands on a moving train
	local base = DepotRules.cruise(out.levels)
	local cruise = base * (if now < out.stokeUntil then STOKE.mult else 1)
	local rem = out.target - out.d
	local v0 = out.speed
	local v1 = if out.coal <= 0
		then math.max(0, v0 - C.COAST * dt)
		elseif v0 < cruise then math.min(cruise, v0 + C.ACCEL * dt)
		else math.max(cruise, v0 - C.ACCEL * dt)
	-- Brake to stop exactly at the target: the largest v1 that, after this tick's move, still sits on
	-- the braking curve v^2 = 2 a (distance left), i.e. v1^2 + a dt v1 = 2 a rem - a dt v0.
	local a = C.ACCEL
	local disc = (a * dt) ^ 2 + 8 * a * rem - 4 * a * dt * v0
	v1 = math.min(v1, if disc > 0 then math.max(0, (math.sqrt(disc) - a * dt) / 2) else 0)
	local step = math.min(rem, (v0 + v1) / 2 * dt)
	local arrived = rem - step <= 1e-3
	out.d = if arrived then out.target else out.d + step
	out.speed = if arrived then 0 else v1
	out.dist = math.min(TrainRules.MAX_DIST, out.dist + step)
	local before = out.coal
	out.coal = math.max(0, out.coal - step * C.COAL_PER_STUD)
	if before >= C.COAL_LOW and out.coal < C.COAL_LOW then
		table.insert(events, { kind = "coalLow", reason = "low" })
	end
	if out.phase == "ride" and out.loot == nil and out.target - out.d <= C.APPROACH then
		local n = TrainRules.activeCount(out, now)
		out.loot = LootRules.build(out.seed, out.leg, out.stop, out.line, n, out.leg == 1 and out.stop == 1)
		table.insert(events, { kind = "approach", n = n })
	end
	if out.phase == "night" and out.night then
		local night = out.night
		if out.target - out.d <= base * base / (2 * C.ACCEL) then
			night = table.clone(night)
			night.nextWave = math.huge -- braking for the Depot or Dawn: no new wave
		end
		local wisps
		night, wisps = WispRules.step(night, {
			now = now,
			dt = dt,
			n = TrainRules.activeCount(out, now),
			leg = out.leg,
			line = out.line,
			lamps = out.levels.lamps,
			beams = input.beams,
			lanterns = input.lanterns,
		})
		out.night = night
		for _, e in wisps do
			table.insert(events, { kind = "wisp", payload = e })
			if e.kind == "dim" then
				out.lantern = math.max(0, out.lantern - (e.amount :: number))
			elseif e.kind == "fed" then
				out.fed = true
				table.insert(events, { kind = "fed" })
			end
		end
	end
	if out.lantern < LANTERN.autoBelow and out.oil >= 1 and now >= out.pourAt + LANTERN.autoEvery - 1e-9 then
		out.lantern += LANTERN.autoPour
		out.oil -= 1
		out.pourAt = now
	end
	if out.lantern <= 0 then
		finishRun(out, now, "lantern", events)
	elseif arrived then
		arrive(out, now, events)
	elseif out.speed <= 0 and out.coal <= 0 then
		finishRun(out, now, "coal", events)
	end
end

function TrainRules.tick(run: Run, input: Input): (Run, { Event })
	local out = copy(run)
	local events: { Event } = {}
	local now = input.now
	if out.phase == "ended" then
		if now < out.phaseAt + C.END_CARD - 1e-9 then
			return out, events
		end
		local fresh = TrainRules.new(Rng.seed(out.seed, now * 1000), now)
		for _, userId in out.order do
			local m = out.crew[userId]
			fresh.crew[userId] = {
				userId = userId,
				joined = m.joined,
				active = m.active,
				seat = nil,
				lastSeat = m.lastSeat,
				limboUntil = nil,
				stokeAt = -math.huge,
				mendAt = -math.huge,
			}
			table.insert(fresh.order, userId)
		end
		table.insert(events, { kind = "hub" })
		return fresh, events
	end
	for userId, m in out.crew do
		m.seat = input.seats[userId]
		if m.seat then
			m.lastSeat = m.seat
		end
	end
	for _, userId in out.order do -- out of the fog: back on the train
		local m = out.crew[userId]
		if m.limboUntil and m.limboUntil > 0 and now >= m.limboUntil then
			local kind = m.seat or pickSeat(out, PREFER[if out.phase == "night" then "night" else "ride"], m.lastSeat)
			m.seat, m.lastSeat = kind, kind or m.lastSeat
			m.limboUntil = if out.phase == "stop" then 0 else nil
			table.insert(events, { kind = "back", userId = userId, payload = kind })
		end
	end
	if out.phase == "ride" or out.phase == "night" then
		moveTick(out, input, events)
	elseif out.phase == "stop" then
		stopTick(out, input, events)
	else
		waitTick(out, now, events)
	end
	return out, events
end

-- Requests (the server checks crew membership, reach and rate first; codes per decision 0018) ----

function TrainRules.stoke(run: Run, userId: number, now: number): (Run, boolean, string?)
	local m = run.crew[userId]
	if m == nil then
		return run, false, "refused"
	elseif run.phase ~= "ride" and run.phase ~= "night" then
		return run, false, "phase"
	elseif m.seat ~= "stoker" then
		return run, false, "seat"
	elseif now - m.stokeAt < STOKE.cooldown - 1e-9 then
		return run, false, "cooldown"
	elseif run.coal < STOKE.coal then
		return run, false, "coal"
	end
	local out = copy(run)
	out.coal -= STOKE.coal
	out.stokeUntil = now + STOKE.seconds
	out.crew[userId].stokeAt, out.crew[userId].active = now, now
	return out, true, nil
end

function TrainRules.mend(run: Run, userId: number, now: number): (Run, boolean, string?)
	local m = run.crew[userId]
	if m == nil then
		return run, false, "refused"
	elseif run.phase == "ended" then
		return run, false, "phase"
	elseif m.seat ~= "mender" then
		return run, false, "seat"
	elseif now - m.mendAt < LANTERN.mendCooldown - 1e-9 then
		return run, false, "cooldown"
	elseif run.oil < 1 then
		return run, false, "oil"
	elseif run.lantern > LANTERN.mendMax then
		return run, false, "full"
	end
	local out = copy(run)
	out.oil -= 1
	out.lantern = math.min(LANTERN.max, out.lantern + LANTERN.mend)
	out.crew[userId].mendAt, out.crew[userId].active = now, now
	return out, true, nil
end

function TrainRules.buy(run: Run, userId: number, id: string): (Run, boolean, string?)
	if run.crew[userId] == nil then
		return run, false, "refused"
	elseif run.phase ~= "depot" then
		return run, false, "phase"
	end
	local pools, ok, code =
		DepotRules.buy({ parts = run.parts, coal = run.coal, oil = run.oil, levels = run.levels }, id)
	if not ok then
		return run, false, code
	end
	local out = copy(run)
	out.parts, out.coal, out.oil, out.levels = pools.parts, pools.coal, pools.oil, pools.levels
	return out, true, nil
end

local VOTES = { hub = { "free", "weekly" }, depot = { "forest", "lake" } }

function TrainRules.vote(run: Run, userId: number, choice: string): (Run, boolean, string?)
	local options = VOTES[run.phase]
	if run.crew[userId] == nil then
		return run, false, "refused"
	elseif options == nil then
		return run, false, "phase"
	elseif not table.find(options, choice) then
		return run, false, "payload"
	end
	local out = copy(run)
	out.votes[userId] = choice
	return out, true, nil
end

local function carryCheck(run: Run, userId: number): string?
	local m = run.crew[userId]
	if m == nil or (m.limboUntil or 0) > 0 then -- caught: hidden in the fog until "back"
		return "refused"
	elseif run.phase ~= "stop" or run.loot == nil then
		return "phase"
	end
	return nil
end

function TrainRules.pick(run: Run, userId: number, itemId: number): (Run, boolean, string?)
	local refusal = carryCheck(run, userId)
	if refusal then
		return run, false, refusal
	end
	local loot = run.loot :: LootRules.Stop
	local ok, code = CarryRules.canPick(loot, run.carries, userId, itemId)
	if not ok then
		return run, false, code
	end
	local out = copy(run)
	out.loot, out.carries = CarryRules.pick(loot, run.carries, userId, itemId)
	return out, true, nil
end

function TrainRules.help(run: Run, userId: number, itemId: number): (Run, boolean, string?)
	local refusal = carryCheck(run, userId)
	if refusal then
		return run, false, refusal
	end
	local loot = run.loot :: LootRules.Stop
	local ok, code = CarryRules.canHelp(loot, run.carries, userId, itemId)
	if not ok then
		return run, false, code
	end
	local out = copy(run)
	out.loot, out.carries = CarryRules.help(loot, run.carries, userId, itemId)
	return out, true, nil
end

function TrainRules.drop(run: Run, userId: number, at: Vec3): (Run, boolean, string?)
	local refusal = carryCheck(run, userId)
	if refusal then
		return run, false, refusal
	end
	local loot = run.loot :: LootRules.Stop
	local after, carries = CarryRules.drop(loot, run.carries, userId, at)
	if after == loot and carries == run.carries then
		return run, false, "refused" -- nothing carried
	end
	local out = copy(run)
	out.loot, out.carries = after, carries
	return out, true, nil
end

function TrainRules.letGo(run: Run, userId: number): Run
	if run.loot == nil then
		return run
	end
	local loot = CarryRules.letGo(run.loot, userId)
	if loot == run.loot then
		return run
	end
	local out = copy(run)
	out.loot = loot
	return out
end

return TrainRules
