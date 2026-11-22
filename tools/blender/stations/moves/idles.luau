local TAU = 2 * math.pi
local LOOP = 4.8 -- seconds an idle takes to come round

local function wave(t: number, period: number, phase: number?): number
	return math.sin(t * TAU / period + (phase or 0))
end

-- 0 outside [start, start + length] of the loop, rising smoothly to 1 in its middle
local function bump(t: number, start: number, length: number): number
	local u = (t % LOOP - start) / length
	return if u >= 0 and u <= 1 then math.sin(math.pi * u) ^ 2 else 0
end

-- 1 inside [start, start + length] of the loop, easing in and out over a quarter second
local function hold(t: number, start: number, length: number): number
	local x = t % LOOP
	local u = math.clamp(math.min((x - start) / 0.25, (start + length - x) / 0.25, 1), 0, 1)
	return u * u * (3 - 2 * u)
end

-- a slow breath laid on a pose: the body swells and the head nods with it
local function breathe(pose: Pose, t: number, deep: number): Pose
	local b, body, head = deep * wave(t, 2.4), pose.body or {}, pose.head or {}
	pose.body = { (body[1] or 0) + b, body[2] or 0, body[3] or 0, body[4] or 0, (body[5] or 0) + 0.02 * b, body[6] or 0 }
	pose.head = {
		(head[1] or 0) + 1.5 * deep * wave(t, 2.4, 0.8),
		head[2] or 0,
		head[3] or 0,
		head[4] or 0,
		head[5] or 0,
		head[6] or 0,
	}
	return pose
end

-- Idles by species: a pose at time t (seconds, any clock), looping every LOOP seconds
AnimalMoves.IDLES = {
	-- Prowling sniff: head low and nose to the ground, it sniffs along, sweeping its head from side to side; now
	-- and then it lifts a forepaw mid-step
	jackal = function(t: number): Pose
		local sniff = 3 * math.sin(t * TAU / 0.24) * (bump(t, 0.3, 1.4) + bump(t, 2.9, 1.3))
		return breathe({
			body = { -4, 0, 0, 0, -0.04, 0 },
			head = { -16 + sniff, 20 * wave(t, LOOP), 0 },
			tail = { 12, 12 * wave(t, 1.6), 0 },
			leg_fr = { 20 * bump(t, 2.2, 0.8) },
			leg_fl = { 4 },
		}, t, 1)
	end,
	-- Old and patient: slowly stretches its neck out and draws it back in, chewing as it goes; one front foot shifts
	-- its weight now and then
	tortoise = function(t: number): Pose
		local reach = wave(t, LOOP)
		return breathe({
			head = {
				-4 + 6 * reach + 2 * math.sin(t * TAU / 0.48) * math.max(0, reach),
				12 * wave(t, LOOP, 1.2),
				0,
				0,
				0.04 * reach,
				-0.12 - 0.18 * reach,
			},
			leg_fl = { 10 * bump(t, 3.4, 0.9) },
		}, t, 0.6)
	end,
	-- Boxer (upright): fists up in a guard, bouncing on its toes and bobbing its head; every so often a quick jab
	meerkat = function(t: number): Pose
		local bob = wave(t, 1.2)
		return {
			body = { -4, 8 * bob, 0, 0, 0.05 * math.abs(math.sin(t * TAU / 1.2)), 0 },
			leg_fl = { 100 + 30 * bump(t, 1.9, 0.32), 0, 0 },
			leg_fr = { 88 + 36 * bump(t, 3.6, 0.32) },
			leg_bl = { 4 + 5 * bob },
			leg_br = { 4 - 5 * bob },
			head = { 6 + 3 * wave(t, 0.6), -6 * bob, 0 },
		}
	end,
	-- Stalking crouch: low on its haunches with its head level and eyes locked ahead, creeping its forepaws one at a
	-- time, tail tip twitching
	cheetah = function(t: number): Pose
		return breathe({
			body = { -3, 0, 0, 0, -0.24, 0 },
			leg_fl = { 42 + 14 * bump(t, 0.6, 0.9) },
			leg_fr = { 42 + 14 * bump(t, 2.9, 0.9) },
			leg_bl = { -24 },
			leg_br = { -24 },
			head = { -6, 6 * wave(t, LOOP), 0 },
			tail = { 6, 10 * math.sin(t * TAU / 0.4) * (bump(t, 1.4, 1.2) + bump(t, 3.8, 0.9)), 0 },
		}, t, 0.6)
	end,
	-- Horn whetting: lowers its head and grinds its horn along the ground from side to side, then lifts it to look
	-- round
	rhino = function(t: number): Pose
		local low = hold(t, 0.3, 2.6)
		return breathe({
			body = { -4 * low, 0, 0, 0, -0.04 * low, 0 },
			head = { -30 * low, 14 * math.sin(t * TAU / 0.8) * low + 18 * wave(t, LOOP, 1) * (1 - low), 0 },
			tail = { 0, 12 * wave(t, 1.2), 0 },
		}, t, 1)
	end,
	-- Preening: turns its long neck round to its wing and nibbles at its feathers, wing lifted, then the other side
	flamingo = function(t: number): Pose
		local left, right = hold(t, 0.3, 1.8), hold(t, 2.7, 1.7)
		local nibble = 3 * math.sin(t * TAU / 0.2) * (hold(t, 0.6, 1.2) + hold(t, 3.0, 1.1))
		return breathe({
			head = { -30 * (left + right) + nibble, 115 * left - 115 * right, 0 },
			leg_bl = { 0, 0, 14 * left },
			leg_br = { 0, 0, -14 * right },
			tail = { 0, 8 * wave(t, 1.2), 0 },
		}, t, 1)
	end,
	-- King's survey: stands tall with its chest out and head high, slowly surveying its land, tail swishing; now and
	-- then a huge yawn
	lion = function(t: number): Pose
		local yawn = bump(t, 3.0, 1.3)
		return breathe({
			body = { 2, 0, 0, 0, 0.02, 0 },
			leg_fl = { -3 },
			leg_fr = { -3 },
			head = { 10 + 24 * yawn, 22 * wave(t, LOOP) * (1 - yawn), 0 },
			tail = { -4, 16 * wave(t, 2.4), 0 },
		}, t, 1)
	end,
	-- Browsing: neck stretched up and forward to the treetops, head turning slowly as it nibbles and chews; tail
	-- swatting flies
	giraffe = function(t: number): Pose
		return breathe({
			head = { 12 + 2 * math.sin(t * TAU / 0.48) * (0.5 + 0.5 * wave(t, 2.4)), 14 * wave(t, LOOP), 0 },
			tail = { 0, 20 * math.sin(t * TAU / 0.6) * bump(t, 2.0, 1.2), 0 },
		}, t, 0.6)
	end,
	-- Swaying giant: rocks its great weight slowly from side to side, lifting each forefoot a little in turn, trunk
	-- swinging, tail swishing
	elephant = function(t: number): Pose
		local sway = wave(t, LOOP)
		return breathe({
			body = { 0, 0, 3 * sway, -0.06 * sway, 0, 0 },
			leg_fl = { 8 * math.max(0, sway) },
			leg_fr = { 8 * math.max(0, -sway) },
			head = { -2 + 2 * wave(t, 2.4), 8 * wave(t, LOOP, 1), 2 * sway },
			tail = { 0, 18 * wave(t, 1.2), 0 },
		}, t, 1)
	end,
} :: { [string]: (number) -> Pose }
