--!strict
-- Pure style-meter rules for Relay Rounds (GDD G). Cosmetic only: the meter never affects
-- who wins, so the client may run it. No Roblox APIs, so Lune can unit-test it.

local StyleRules = {}

export type State = { points: number, last: string?, streak: number }

StyleRules.MAX = 240
StyleRules.DECAY = 7 -- points per second

StyleRules.POINTS = {
	doubleJump = 8,
	dash = 10,
	launch = 14,
	boost = 8,
	legClear = 20,
	airtime = 6, -- per second airborne
}

StyleRules.RANKS = {
	{ min = 0, letter = "D", name = "Dull" },
	{ min = 20, letter = "C", name = "Cool" },
	{ min = 45, letter = "B", name = "Bravo" },
	{ min = 75, letter = "A", name = "Awesome" },
	{ min = 110, letter = "S", name = "Stylish" },
	{ min = 150, letter = "SS", name = "Spectacular" },
	{ min = 200, letter = "SSS", name = "Sensational" },
}

function StyleRules.new(): State
	return { points = 0, last = nil, streak = 0 }
end

-- Repeating the same move in a row earns less each time (full, 1/2, 1/3, ...), so variety pays.
function StyleRules.add(state: State, event: string): State
	local base = StyleRules.POINTS[event]
	if base == nil then
		return state
	end
	local streak = if state.last == event then state.streak + 1 else 0
	local points = math.min(StyleRules.MAX, state.points + base / (1 + streak))
	return { points = points, last = event, streak = streak }
end

-- Airtime earns points continuously and doesn't count as a repeat.
function StyleRules.airtime(state: State, dt: number): State
	return {
		points = math.min(StyleRules.MAX, state.points + StyleRules.POINTS.airtime * dt),
		last = state.last,
		streak = state.streak,
	}
end

function StyleRules.decay(state: State, dt: number): State
	return { points = math.max(0, state.points - StyleRules.DECAY * dt), last = state.last, streak = state.streak }
end

-- Falling or getting hit wipes the meter.
function StyleRules.reset(): State
	return StyleRules.new()
end

-- Index into RANKS for a points total.
function StyleRules.rank(points: number): number
	local index = 1
	for i, r in StyleRules.RANKS do
		if points >= r.min then
			index = i
		end
	end
	return index
end

return StyleRules
