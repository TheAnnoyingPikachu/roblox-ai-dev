--!strict
-- Lantern Express nights (architecture lantern 3.5, GDD C4, E): waves of shadow wisps drifting at
-- the train's lanterns, the server's beam test, and the Lampeater on leg 3. Everything is in the
-- train frame (-z forward, origin at the engine's front), so a moving train never changes an aim.
-- A wisp's path is a pure function of its spawn record, so clients draw it with `pos` and the
-- server tests the same positions. Times are GetServerTimeNow floats. No Roblox APIs.

local LanternConfig = require("./LanternConfig")
local Rng = require("./Rng")

local WispRules = {}

type Vec3 = LanternConfig.Vec3
export type Wisp = {
	id: number,
	born: number,
	from: Vec3,
	target: Vec3,
	speed: number,
	phase: number,
	lit: number, -- beam-seconds so far (adds across beams)
	state: "drift" | "puffed" | "dimmed",
}
export type Dive = { at: number, target: Vec3, lit: number }
export type Lampeater = {
	born: number,
	fed: number,
	need: number,
	nextDive: number,
	dive: Dive?,
	gone: ("fed" | "dawn")?,
}
export type Night = {
	started: number,
	wave: number,
	nextWave: number,
	nextId: number,
	rng: Rng.State,
	wisps: { [number]: Wisp },
	lampeater: Lampeater?,
}
export type Beam = { origin: Vec3, dir: Vec3 } -- dir is a unit vector
export type Event = {
	kind: "spawn" | "puff" | "dim" | "lampeater" | "dive" | "shoo" | "fed",
	wisps: { Wisp }?,
	ids: { number }?,
	amount: number?,
	target: Vec3?,
}
export type StepInput = {
	now: number,
	dt: number,
	n: number,
	leg: number,
	line: LanternConfig.Line,
	lamps: number,
	beams: { Beam },
	lanterns: { Vec3 },
}

local WAVES, BEAM, LAMPEATER = LanternConfig.WAVES, LanternConfig.BEAM, LanternConfig.LAMPEATER
local MID = { x = 0, y = 0, z = LanternConfig.TRAIN_LENGTH / 2 } -- the train's middle
local CIRCLE_SPEED = 2 * math.pi / 16 -- the Lampeater laps the train every 16 s
local COS_HALF = math.cos(math.rad(BEAM.halfAngle))

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end
local function sub(a: Vec3, b: Vec3): Vec3
	return v(a.x - b.x, a.y - b.y, a.z - b.z)
end
local function len(a: Vec3): number
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end
local function lerp(a: Vec3, b: Vec3, t: number): Vec3
	return v(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
end

function WispRules.new(now: number, seed: number, leg: number): Night
	return {
		started = now,
		wave = 0,
		nextWave = now + WAVES.first,
		nextId = 1,
		rng = Rng.seed(seed, leg, 99),
		wisps = {},
		lampeater = nil,
	}
end

function WispRules.waveSize(n: number, leg: number, line: LanternConfig.Line): number
	n = math.max(1, math.floor(n))
	local k = math.min(n, 4) -- four turrets; a fifth and sixth player add one wisp each
	local per = WAVES.perTurret[math.clamp(leg, 1, 3)]
	return per * k + (n - k) + (if line == "lake" then WAVES.lake else 0)
end

function WispRules.dimPer(n: number): number
	return LanternConfig.DIM[math.clamp(math.floor(n), 1, 4)]
end

-- Drift speed by crew size: a lone lamp has the whole circle to cover, so its wisps come slower.
function WispRules.speed(n: number): number
	return WAVES.speed[math.clamp(math.floor(n), 1, 4)]
end

-- Straight drift from `from` to `target`, plus a wobble of at most WAVES.wobble studs (so a wisp
-- at its target is always inside WAVES.reach).
function WispRules.pos(w: Wisp, now: number): Vec3
	local t = math.max(0, now - w.born)
	local way = sub(w.target, w.from)
	local dist = len(way)
	local p = if dist > 0 then lerp(w.from, w.target, math.min(t * w.speed, dist) / dist) else w.from
	local a = WAVES.wobble
	return v(p.x + 0.6 * a * math.sin(1.7 * t + w.phase), p.y + 0.8 * a * math.cos(1.3 * t + w.phase), p.z)
end

local function circle(l: Lampeater, t: number): Vec3
	local angle = (t - l.born) * CIRCLE_SPEED
	return v(MID.x + LAMPEATER.radius * math.cos(angle), LAMPEATER.height, MID.z + LAMPEATER.radius * math.sin(angle))
end

-- On its circle, or during a dive down to the dive's lantern (first half) and back up (second).
function WispRules.lampeaterPos(l: Lampeater, now: number): Vec3
	local dive = l.dive
	if dive and now >= dive.at and now < dive.at + LAMPEATER.dive then
		local s = (now - dive.at) / LAMPEATER.dive
		if s < 0.5 then
			return lerp(circle(l, dive.at), dive.target, s * 2)
		end
		return lerp(dive.target, circle(l, dive.at + LAMPEATER.dive), s * 2 - 1)
	end
	return circle(l, now)
end

function WispRules.lit(beam: Beam, point: Vec3, range: number): boolean
	local q = sub(point, beam.origin)
	local d = len(q)
	if d > range then
		return false
	elseif d < 1e-6 then
		return true
	end
	return (q.x * beam.dir.x + q.y * beam.dir.y + q.z * beam.dir.z) / d >= COS_HALF
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and math.abs(x) ~= math.huge
end

-- A client's aim: nil unless three finite numbers of length 0.5 to 1.5; normalised, pitch clamped.
function WispRules.clampAim(dir: any): Vec3?
	if type(dir) ~= "table" or not (finite(dir.x) and finite(dir.y) and finite(dir.z)) then
		return nil
	end
	local l = len(dir)
	if l < 0.5 or l > 1.5 then
		return nil
	end
	local x, y, z = dir.x / l, dir.y / l, dir.z / l
	local pitch = math.clamp(math.asin(math.clamp(y, -1, 1)), math.rad(BEAM.pitchMin), math.rad(BEAM.pitchMax))
	local flat = math.sqrt(x * x + z * z)
	if flat < 1e-6 then
		x, z, flat = 0, -1, 1 -- straight up or down: keep facing forward
	end
	local scale = math.cos(pitch) / flat
	return v(x * scale, math.sin(pitch), z * scale)
end

-- True when the aim `to` turned more than CREW.aimTurn degrees from `from` (nil: the first aim). Only
-- a turned aim counts as activity (QA M3); the client's keep-alive re-send of the same aim does not.
function WispRules.turned(from: Vec3?, to: Vec3): boolean
	if from == nil then
		return true
	end
	local dot = (from.x * to.x + from.y * to.y + from.z * to.z) / math.max(len(from) * len(to), 1e-9)
	return math.deg(math.acos(math.clamp(dot, -1, 1))) > LanternConfig.CREW.aimTurn
end

local function copy(night: Night): Night
	local out = table.clone(night)
	out.wisps = {}
	for id, w in night.wisps do
		out.wisps[id] = table.clone(w)
	end
	if night.lampeater then
		local l = table.clone(night.lampeater)
		l.dive = if l.dive then table.clone(l.dive) else nil
		out.lampeater = l
	end
	return out
end

local function pickLantern(out: Night, lanterns: { Vec3 }): Vec3
	if #lanterns == 0 then
		return v(MID.x, 6, MID.z)
	end
	local i
	i, out.rng = Rng.int(out.rng, 1, #lanterns)
	return table.clone(lanterns[i])
end

local function spawnWave(out: Night, input: StepInput, at: number): { Wisp }
	local size = WispRules.waveSize(input.n, input.leg, input.line)
	local list = {}
	for i = 1, size do
		local a, r, h, phase
		a, out.rng = Rng.next(out.rng)
		r, out.rng = Rng.next(out.rng)
		h, out.rng = Rng.next(out.rng)
		phase, out.rng = Rng.next(out.rng)
		local dist = WAVES.spawnMin + r * (WAVES.spawnMax - WAVES.spawnMin)
		local w: Wisp = {
			id = out.nextId,
			born = at + (i - 1) * WAVES.spread / size,
			from = v(
				MID.x + dist * math.cos(a * 2 * math.pi),
				WAVES.heightMin + h * (WAVES.heightMax - WAVES.heightMin),
				MID.z + dist * math.sin(a * 2 * math.pi)
			),
			target = pickLantern(out, input.lanterns),
			speed = WispRules.speed(input.n),
			phase = phase * 2 * math.pi,
			lit = 0,
			state = "drift",
		}
		out.nextId += 1
		out.wisps[w.id] = w
		table.insert(list, table.clone(w))
	end
	return list
end

local function beamsOn(beams: { Beam }, p: Vec3, range: number): number
	local k = 0
	for _, beam in beams do
		if WispRules.lit(beam, p, range) then
			k += 1
		end
	end
	return k
end

function WispRules.step(night: Night, input: StepInput): (Night, { Event })
	local out = copy(night)
	local events: { Event } = {}
	local now, dt = input.now, input.dt
	local lamps = math.clamp(input.lamps, 1, 3)
	local range, puffAt = BEAM.range[lamps], BEAM.puff[lamps]
	-- Waves (leg 3: none at or after the Lampeater's time).
	local cutoff = if input.leg >= 3 then out.started + LAMPEATER.at else math.huge
	while now >= out.nextWave do
		if out.nextWave >= cutoff then
			out.nextWave = math.huge
			break
		end
		table.insert(events, { kind = "spawn", wisps = spawnWave(out, input, out.nextWave) })
		out.wave += 1
		out.nextWave += WAVES.gap
	end
	-- Exposure (dt per beam per tick, so a faster aim stream never puffs faster), then arrivals.
	local ids = {}
	for id in out.wisps do
		table.insert(ids, id)
	end
	table.sort(ids)
	local puffed = {}
	for _, id in ids do
		local w = out.wisps[id]
		if w.born <= now then
			local p = WispRules.pos(w, now)
			w.lit += dt * beamsOn(input.beams, p, range)
			if w.lit >= puffAt - 1e-9 then
				w.state = "puffed"
				table.insert(puffed, id)
				out.wisps[id] = nil
			elseif len(sub(p, w.target)) <= WAVES.reach then
				w.state = "dimmed"
				table.insert(events, { kind = "dim", ids = { id }, amount = WispRules.dimPer(input.n) })
				out.wisps[id] = nil
			end
		end
	end
	if #puffed > 0 then
		table.insert(events, { kind = "puff", ids = puffed })
	end
	-- The Lampeater (leg 3): announced WARN s ahead, then circles, dives and can be fed.
	if input.leg >= 3 and out.lampeater == nil and now >= out.started + LAMPEATER.at - LAMPEATER.warn then
		local born = out.started + LAMPEATER.at
		out.lampeater = {
			born = born,
			fed = 0,
			need = LAMPEATER.needBase + LAMPEATER.needPer * (math.max(1, input.n) - 1),
			nextDive = born + LAMPEATER.every,
			dive = nil,
			gone = nil,
		}
		table.insert(events, { kind = "lampeater" })
	end
	local l = out.lampeater
	if l and l.gone == nil and now >= l.born then
		local on = beamsOn(input.beams, WispRules.lampeaterPos(l, now), range)
		l.fed += dt * on
		local dive = l.dive
		if dive then
			dive.lit += dt * on
		end
		if l.fed >= l.need - 1e-9 then
			l.gone, l.dive = "fed", nil
			table.insert(events, { kind = "fed" })
		elseif dive and now >= dive.at + LAMPEATER.dive then
			if dive.lit >= LAMPEATER.shoo - 1e-9 then
				table.insert(events, { kind = "shoo", target = dive.target })
			else
				table.insert(events, { kind = "dim", amount = LAMPEATER.dim, target = dive.target })
			end
			l.dive = nil
		end
		if l.gone == nil and l.dive == nil and now >= l.nextDive then
			l.dive = { at = l.nextDive, target = pickLantern(out, input.lanterns), lit = 0 }
			l.nextDive += LAMPEATER.every
			table.insert(events, { kind = "dive", target = (l.dive :: Dive).target })
		end
	end
	return out, events
end

return WispRules
