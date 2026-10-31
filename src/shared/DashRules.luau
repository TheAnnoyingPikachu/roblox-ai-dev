--!strict
-- Pure Splash Dash rules (GDD T, decision 0012): the round state machine, the server's checks on
-- each 5 Hz root sample, and the obstacle motion and knockback the clients run. Times are floats
-- from the server's GetServerTimeNow. Functions return new tables and never mutate their inputs.
-- No Roblox APIs.

local GardenConfig = require("./GardenConfig")

local DashRules = {}

export type Vec3 = { x: number, y: number, z: number }
export type Phase = "idle" | "countdown" | "starting" | "racing"
export type Entrant = { id: number, eligible: boolean } -- id: UserId
export type Racer = {
	next: number, -- index in DASH.checkpoints of the checkpoint to reach next
	eligible: boolean, -- may take the egg
	strikes: number,
	lastPos: Vec3?, -- last sample that differed, or where the server last moved the racer
	lastAt: number, -- server time of lastPos
	legAt: number, -- when this leg began: GO, the last checkpoint or the last server teleport
	settleUntil: number, -- samples before this time are ignored
	arriving: boolean, -- teleported, and no sample has shown the racer at lastPos yet
	finished: number?, -- seconds from GO
	out: boolean, -- left or struck out
}
export type Round = {
	phase: Phase,
	ready: { number }, -- UserIds in ready order; survives a running round (the next round's queue)
	at: number, -- countdown end (countdown), GO (starting), when the round ends (racing); 0 in idle
	goAt: number,
	racers: { [number]: Racer },
	places: number, -- finishers so far
	winner: number?, -- first finisher
	prizeTo: number?, -- first eligible finisher
}
export type Event = {
	kind: string, -- "start" | "go" | "checkpoint" | "splash" | "flag" | "out" | "finish" | "over"
	id: number?, -- the racer
	ids: { number }?, -- start: racers in spot order; over: racers still in the round
	cp: number?, -- checkpoint: reached; splash, flag: the checkpoint to return to (0 = start)
	place: number?, -- finish
	time: number?, -- finish: seconds from GO
	egg: boolean?, -- finish: this finisher takes the egg
	winner: number?, -- over
	prizeTo: number?, -- over
	reason: string?, -- over: "finished" | "time" | "empty"
}
export type Pose = { x: number, y: number, z: number, angle: number } -- angle in radians

local DASH = GardenConfig.DASH

local DECK_UP = 4 -- respawn and start spots stand this far above the deck
local SPOT_GAP = 6
local KNOCK_UP = 20
local ARM_WIDTH = 2.5
local ARM_HEIGHT = 6
local HIT_MARGIN = 2
local ARRIVE = 30 -- under the 31 studs a sample may move, so a near stale sample cannot cause a strike
local ARRIVE_HOLD = 2 -- seconds past settle a racer may take to show up at a teleport's target

-- A leg's floor is its share of minFinish by length, so the floors add up to minFinish and a racer
-- who stands still and then jumps ahead still takes at least that long (GDD T7).
local LEG_MIN: { number } = {}
do
	local from, total = DASH.start, 0
	for i, spot in DASH.checkpoints do
		LEG_MIN[i] = math.sqrt((spot.x - from.x) ^ 2 + (spot.z - from.z) ^ 2)
		total += LEG_MIN[i]
		from = spot
	end
	for i, length in LEG_MIN do
		LEG_MIN[i] = length / total * DASH.minFinish
	end
end

local function copy(r: Round): Round
	local out = table.clone(r)
	out.ready = table.clone(r.ready)
	out.racers = {}
	for id, racer in r.racers do
		out.racers[id] = table.clone(racer)
	end
	return out
end

-- Starts or cancels the countdown after `ready` changed; running rounds ignore the queue.
local function queue(out: Round, t: number)
	if out.phase == "idle" and #out.ready >= DASH.minPlayers then
		out.phase = "countdown"
		out.at = t + DASH.countdown
	elseif out.phase == "countdown" and #out.ready < DASH.minPlayers then
		out.phase = "idle"
		out.at = 0
	end
end

function DashRules.new(): Round
	return { phase = "idle", ready = {}, at = 0, goAt = 0, racers = {}, places = 0 }
end

function DashRules.isReady(r: Round, id: number): boolean
	return table.find(r.ready, id) ~= nil
end

function DashRules.isRacer(r: Round, id: number): boolean
	local racer = r.racers[id]
	return racer ~= nil and not racer.out
end

function DashRules.status(r: Round): { [string]: any }
	local racers: { number } = {}
	for id, racer in r.racers do
		if not racer.out then
			table.insert(racers, id)
		end
	end
	table.sort(racers) -- GardenStatus is only rewritten when its JSON changes
	return {
		phase = r.phase,
		ready = table.clone(r.ready),
		need = DASH.minPlayers,
		at = r.at,
		goAt = r.goAt,
		racers = racers,
	}
end

function DashRules.setReady(r: Round, id: number, ready: boolean, t: number): (Round, boolean)
	local at = table.find(r.ready, id)
	if DashRules.isRacer(r, id) or (at ~= nil) == ready or (ready and #r.ready >= DASH.maxPlayers) then
		return r, false
	end
	local out = copy(r)
	if at then
		table.remove(out.ready, at)
	else
		table.insert(out.ready, id)
	end
	queue(out, t)
	return out, true
end

function DashRules.start(r: Round, t: number, entrants: { Entrant }): (Round, { Event })
	if r.phase ~= "countdown" or t < r.at then
		return r, {}
	end
	local out = DashRules.new()
	local ids: { number } = {}
	for _, e in entrants do
		table.insert(ids, e.id)
	end
	if #ids < DASH.minPlayers then
		out.ready = ids
		return out, {}
	end
	out.phase = "starting"
	out.at = t + DASH.starting
	out.goAt = out.at
	for _, e in entrants do
		out.racers[e.id] = {
			next = 1,
			eligible = e.eligible,
			strikes = 0,
			lastAt = t,
			legAt = out.goAt,
			settleUntil = t + DASH.settle,
			arriving = false,
			out = false,
		}
	end
	return out, { { kind = "start", ids = ids } }
end

local function over(r: Round, t: number, reason: string): (Round, { Event })
	local out = DashRules.new()
	out.ready = table.clone(r.ready)
	queue(out, t)
	local ids = DashRules.status(r).racers
	return out, { { kind = "over", ids = ids, winner = r.winner, prizeTo = r.prizeTo, reason = reason } }
end

local function running(r: Round): boolean
	for _, racer in r.racers do
		if not racer.out and racer.finished == nil then
			return true
		end
	end
	return false
end

function DashRules.step(r: Round, t: number): (Round, { Event })
	if r.phase == "starting" and t >= r.at then
		local out = copy(r)
		out.phase = "racing"
		out.at = r.goAt + DASH.limit
		return out, { { kind = "go" } }
	elseif r.phase == "racing" and (t >= r.at or not running(r)) then
		local left = #DashRules.status(r).racers
		return over(r, t, if r.winner then "finished" elseif left == 0 then "empty" else "time")
	elseif r.phase == "idle" and #r.ready >= DASH.minPlayers then
		local out = copy(r)
		queue(out, t)
		return out, {}
	end
	return r, {}
end

function DashRules.inZone(pos: Vec3, spot: Vec3): boolean
	local dx, dz = pos.x - spot.x, pos.z - spot.z
	local radius = DASH.zone.radius
	return dx * dx + dz * dz <= radius * radius and math.abs(pos.y - spot.y) <= DASH.zone.height
end

-- One strike: back to the last checkpoint, or out of the round at maxStrikes. Never a fall.
local function strike(racer: Racer, id: number, events: { Event })
	racer.strikes += 1
	if racer.strikes >= DASH.maxStrikes then
		racer.out = true
		table.insert(events, { kind = "out", id = id })
	else
		table.insert(events, { kind = "flag", id = id, cp = racer.next - 1 })
	end
end

local function finish(out: Round, racer: Racer, id: number, t: number, events: { Event })
	local time = t - out.goAt
	out.places += 1
	racer.finished = time
	if out.winner == nil then
		out.winner = id
		out.at = math.min(out.at, t + DASH.grace)
	end
	local egg = out.prizeTo == nil and racer.eligible
	if egg then
		out.prizeTo = id
	end
	table.insert(events, { kind = "finish", id = id, place = out.places, time = time, egg = egg })
end

-- The floor on one leg, in seconds: checkpoint `cp` counts this long after the leg began.
function DashRules.legMin(cp: number): number
	return LEG_MIN[cp]
end

-- Architecture section 3.8: settle, arrival, speed, fall, zone. The root position is client-owned,
-- so the speed check is written to fail on NaN.
function DashRules.sample(r: Round, id: number, pos: Vec3, t: number): (Round, { Event })
	local before = r.racers[id]
	if r.phase ~= "racing" or before == nil or before.out or t < before.settleUntil then
		return r, {}
	end
	if before.finished then
		-- Nothing else matters now, but the deck has edges and the catcher is no place to wait.
		return r, if pos.y < DASH.fellY then { { kind = "splash", id = id, cp = before.next - 1 } } else {}
	end
	local target = before.lastPos
	if before.arriving and target and t < before.settleUntil + ARRIVE_HOLD then
		-- Far from the target this is a stale sample on a slow connection: wait for the real one.
		local dx, dz = pos.x - target.x, pos.z - target.z
		if dx * dx + dz * dz > ARRIVE * ARRIVE then
			return r, {}
		end
	end
	local out = copy(r)
	local racer = out.racers[id]
	racer.arriving = false
	local events: { Event } = {}
	local last = racer.lastPos
	local moved = last == nil or pos.x ~= last.x or pos.y ~= last.y or pos.z ~= last.z
	if moved then
		if last then
			local dx, dz = pos.x - last.x, pos.z - last.z
			if not (math.sqrt(dx * dx + dz * dz) <= DASH.maxSpeed * (t - racer.lastAt) + DASH.slack + 1e-9) then
				strike(racer, id, events)
				return out, events
			end
		end
		racer.lastPos = { x = pos.x, y = pos.y, z = pos.z }
		racer.lastAt = t
	end
	if pos.y < DASH.fellY then
		table.insert(events, { kind = "splash", id = id, cp = racer.next - 1 })
	elseif
		DashRules.inZone(pos, DASH.checkpoints[racer.next])
		and t - racer.legAt + 1e-9 >= LEG_MIN[racer.next] -- early: no event and no strike, it counts once due
	then
		racer.legAt = t
		if racer.next < #DASH.checkpoints then
			racer.next += 1
			table.insert(events, { kind = "checkpoint", id = id, cp = racer.next - 1 })
		else
			finish(out, racer, id, t, events)
		end
	end
	return out, events
end

-- After any server teleport. `at` is the target: the next samples are measured from it, and a fall
-- or flag restarts the leg's floor, so being sent back never shortens the next hop.
function DashRules.teleported(r: Round, id: number, t: number, at: Vec3): Round
	if r.racers[id] == nil then
		return r
	end
	local out = copy(r)
	local racer = out.racers[id]
	racer.lastPos = { x = at.x, y = at.y, z = at.z }
	racer.lastAt = t
	racer.legAt = math.max(t, r.goAt)
	racer.settleUntil = t + DASH.settle
	racer.arriving = true
	return out
end

function DashRules.leave(r: Round, id: number, t: number): (Round, { Event })
	local at = table.find(r.ready, id)
	local racing = DashRules.isRacer(r, id)
	if at == nil and not racing then
		return r, {}
	end
	local out = copy(r)
	if at then
		table.remove(out.ready, at)
	end
	if racing then
		out.racers[id].out = true
		if #DashRules.status(out).racers == 0 then
			return over(out, t, "empty")
		end
	end
	queue(out, t)
	return out, {}
end

function DashRules.respawnCp(r: Round, id: number): number
	local racer = r.racers[id]
	return if racer then racer.next - 1 else 0
end

function DashRules.respawnPoint(cp: number): Vec3
	local spot = DASH.checkpoints[cp] or DASH.start
	return { x = spot.x, y = spot.y + DECK_UP, z = spot.z }
end

function DashRules.startSpot(i: number): Vec3
	local s = DASH.start
	return { x = s.x, y = s.y + DECK_UP, z = s.z + (i - (DASH.maxPlayers + 1) / 2) * SPOT_GAP }
end

-- The way to face at checkpoint `cp` (0 = start): flat, towards the next checkpoint. For `cp` 0 to
-- one before the finish, which is every place a racer is sent.
function DashRules.facing(cp: number): Vec3
	local from, to = DASH.checkpoints[cp] or DASH.start, DASH.checkpoints[cp + 1]
	return { x = to.x - from.x, y = 0, z = to.z - from.z }
end

-- Obstacles -----------------------------------------------------------------------------------

-- Pure in server time, the same for every client and round. A sweeper's angle follows
-- CFrame.Angles(0, angle, 0): its arms lie along local x, world (cos a, -sin a) in x, z. A
-- pendulum's angle is its tilt from straight down towards +axis.
function DashRules.pose(o: GardenConfig.Obstacle, t: number): Pose
	local c = 2 * math.pi * (t / o.period + o.phase)
	local y, shift, angle = o.at.y, 0, 0
	if o.kind == "sweeper" then
		angle = c
	elseif o.kind == "pendulum" then
		angle = math.rad(DASH.swing) * math.sin(c)
		shift = o.reach * math.sin(angle)
		y -= o.reach * math.cos(angle)
	else
		shift = o.reach * math.sin(c)
		if o.kind == "ball" then
			y += o.size + (o.lift or 0) * math.abs(math.cos(c))
		end
	end
	return {
		x = o.at.x + if o.axis == "x" then shift else 0,
		y = y,
		z = o.at.z + if o.axis == "z" then shift else 0,
		angle = angle,
	}
end

local function limited(x: number, y: number, z: number): Vec3
	local scale = math.min(1, DASH.knockMax / math.sqrt(x * x + y * y + z * z))
	return { x = x * scale, y = y * scale, z = z * scale }
end

-- Velocity for a hit, else nil. "Away" is horizontal, so a root under a ball is shoved aside
-- rather than into the deck; straight below the centre it goes towards +x.
function DashRules.knock(o: GardenConfig.Obstacle, pose: Pose, root: Vec3): Vec3?
	if o.kind == "platform" then
		return nil
	end
	local dx, dy, dz = root.x - pose.x, root.y - pose.y, root.z - pose.z
	if o.kind == "sweeper" then
		local ax, az = math.cos(pose.angle), -math.sin(pose.angle)
		local along = dx * ax + dz * az
		local on = math.clamp(along, -o.size, o.size)
		local ex, ez = dx - on * ax, dz - on * az
		if dy < 0 or dy > ARM_HEIGHT or ex * ex + ez * ez > ARM_WIDTH * ARM_WIDTH then
			return nil
		end
		local side = if along < 0 then -o.knock else o.knock
		return limited(az * side, KNOCK_UP, -ax * side)
	end
	local reach = o.size + HIT_MARGIN
	if dx * dx + dy * dy + dz * dz > reach * reach then
		return nil
	end
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat < 1e-6 then
		return limited(o.knock, KNOCK_UP, 0)
	end
	return limited(dx / flat * o.knock, KNOCK_UP, dz / flat * o.knock)
end

return DashRules
