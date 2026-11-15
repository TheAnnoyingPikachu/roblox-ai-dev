--!strict
-- Pure numbers for the fight presentation (decision 0048): when a ranged attack starts, how long a
-- projectile flies, how long a hit freezes, how hard a target flinches, how a camera punch fades.
-- Display only: nothing here may decide, delay or change a fight's result. No Roblox APIs.

local FightFx = {}

FightFx.LEAD = 0.45 -- seconds an attack's animation starts before its hit lands
FightFx.POWER_LEAD = 0.92 -- and a power attack's (its slam is 0.92 s into the clip)
FightFx.RELEASE = 0.46 -- seconds into an archer's or mage's clip when the arrow or bolt is let go
FightFx.SPEED = 70 -- studs a second a projectile flies at
FightFx.PUNCH_SECONDS = 0.6

-- Seconds a projectile flies over `distance` studs: quick, but long enough to be seen.
function FightFx.flightTime(distance: number): number
	return math.clamp(distance / FightFx.SPEED, 0.18, 0.7)
end

-- Seconds before the hit that the attacker's animation starts. A shot (`flight` seconds in the
-- air) starts early enough for its release to come `flight` before the hit.
function FightFx.lead(power: boolean, flight: number?): number
	if power then
		return FightFx.POWER_LEAD
	elseif flight then
		return FightFx.RELEASE + flight
	end
	return FightFx.LEAD
end

-- Seconds a fighter's animation holds still on a hit: 0.06 for a normal one, 0.1 for a power one,
-- 0.2 for the killing blow of the fight.
function FightFx.hitStop(power: number, final: boolean?): number
	if final then
		return 0.2
	end
	return 0.06 + 0.04 * math.clamp(power, 0, 1)
end

-- How much the target's flinch is stretched: a power hit and a big share of its health both add.
function FightFx.flinch(power: number, share: number): number
	return 1 + 0.6 * math.clamp(power, 0, 1) + math.min(0.6, math.max(0, share) * 2)
end

-- How strongly the camera punches on a hit (0 to 1).
function FightFx.punchStrength(power: number): number
	return if power > 0 then 1 else 0.35
end

-- The camera punch `age` seconds after a hit: full strength at once, gone after PUNCH_SECONDS.
function FightFx.punch(age: number, strength: number): number
	if age < 0 or age > FightFx.PUNCH_SECONDS then
		return 0
	end
	return strength * math.exp(-age * 9)
end

local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

FightFx.SLOW_SECONDS = 1.5
FightFx.CUT_SECONDS = 1.3

-- How fast clips play `age` seconds after the fight's killing blow: slow motion at 0.3 for 0.8 s,
-- then back to full speed by SLOW_SECONDS. Display only: the server's clock never slows.
function FightFx.slow(age: number): number
	if age < 0 or age >= FightFx.SLOW_SECONDS then
		return 1
	elseif age < 0.8 then
		return 0.3
	end
	return 0.3 + 0.7 * ease((age - 0.8) / (FightFx.SLOW_SECONDS - 0.8))
end

-- How far the camera is cut in towards a hit (0 to 1) `age` seconds after it: in quickly, held, out.
function FightFx.cut(age: number): number
	if age < 0 or age > FightFx.CUT_SECONDS then
		return 0
	elseif age < 0.18 then
		return ease(age / 0.18)
	elseif age < 0.9 then
		return 1
	end
	return 1 - ease((age - 0.9) / (FightFx.CUT_SECONDS - 0.9))
end

return FightFx
