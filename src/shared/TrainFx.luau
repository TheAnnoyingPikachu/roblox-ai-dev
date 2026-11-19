--!strict
-- Timings of the training animations (decision 0067): an animal's clip and the kit it trains with are
-- drawn by different scripts on each client, both from the server's clock through these, so the ram
-- lands as the animal is thrown back and the bar sinks as it does. Pure: no Roblox API. Display only:
-- nothing here decides or delays any training.

local TrainFx = {}

TrainFx.HEAVE = 2.8 -- seconds a lift takes (the Strength Gym)
TrainFx.BRACE = 2.4 -- seconds between a ram's blows (the Guard Yard)
TrainFx.SWING = 30 -- degrees a ram swings back from the animal

local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

-- 0 to 1 over the first `rise` of a turn, back to 0 by `fall`, then rest.
function TrainFx.pulse(u: number, rise: number, fall: number): number
	return if u < rise then ease(u / rise) elseif u < fall then 1 - ease((u - rise) / (fall - rise)) else 0
end

-- A lift at `time`: how far down the animal is under the weight (0 standing to 1 at the bottom), and how
-- far through the lift it is (0 to 1). It sinks, shakes at the bottom, drives up, stands.
function TrainFx.heave(time: number): (number, number)
	local u = (time % TrainFx.HEAVE) / TrainFx.HEAVE
	return TrainFx.pulse(u, 0.35, 0.62), u
end

-- What the animal pushes (the gym's boulder) at `time`: 0 at rest to 1 pushed furthest. It goes as the
-- animal drives up and rolls back while it stands.
function TrainFx.push(time: number): number
	local u = (time % TrainFx.HEAVE) / TrainFx.HEAVE
	return if u < 0.35 then 0 else TrainFx.pulse((u - 0.35) / 0.65, 0.42, 0.95)
end

-- A blow at `time`: how far the animal is thrown back (0 set to 1 at the worst of it). The blow lands
-- as a turn begins.
function TrainFx.brace(time: number): number
	return TrainFx.pulse((time % TrainFx.BRACE) / TrainFx.BRACE, 0.07, 0.4)
end

-- The ram at `time`: 0 against the animal to 1 at the far end of its swing, back as the next blow lands.
function TrainFx.swing(time: number): number
	return math.sin(math.pi * (time % TrainFx.BRACE) / TrainFx.BRACE)
end

return TrainFx
