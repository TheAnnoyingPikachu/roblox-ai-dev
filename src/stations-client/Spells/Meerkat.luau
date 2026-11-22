--!strict
-- The meerkats' spells (magic.py's meerkat and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env = S.C, S.Z, S.ease, S.seg, S.env
	local TAU = S.TAU

	return {
		-- Sun Orb: Holds its paws up and gathers a little sun overhead, rays turning round it, then hurls it at the
		-- target.
		meerkat = function(f)
			local k, t = f.k, f.t
			local hands = (f.A.paw_l + f.A.paw_r) / 2
			local grow = seg(t, 0.2, 0.7)
			if grow ~= nil then
				local p = hands + Z(0.5 * k)
				local R = 0.9 * k * ease(grow)
				f.kit:orb(p, R, C.SUN, 7, 1, nil, 4)
				for i = 0, 7 do -- rays turning round it
					local a = t * 4 + i / 8 * TAU
					local d = f.V(0.2 * math.sin(a), math.cos(a), math.sin(a))
					f.kit:spike(p + d * R, p + d * R * 1.9, 0.12 * k, C.SUN, 7, 0.8 * ease(grow))
				end
			end
			S.flight(f, hands + Z(0.5 * k), f.TC, 0.7, S.IMPACT, 2.5 * k, function(p: Vector3)
				f.kit:orb(p, 0.9 * k, C.SUN, 8, 1, nil, 4)
			end, { C.SUN, 0.8 * k })
			S.impact(f, C.SUN, 3.5, 11)
			local u = seg(t, S.IMPACT, S.IMPACT + 0.45)
			if u ~= nil then
				f.kit:orb(f.TC, (1 + 2.6 * ease(u)) * k, C.FIRE, 5, 0.6 * (1 - u), false)
			end
		end,

		-- Comet Strike: Points to the sky with a line of starlight; a comet streaks across the sky and crashes onto the
		-- target in a shower of stars.
		creature_meerkat_star_forge = function(f)
			local k, t = f.k, f.t
			local hand = f.A.paw_r
			f.kit:aura(C.STAR, 0.2 * env(t, 0.25, 0.4, 0.82, 0.92))
			local far = f.T + f.V(6, 10, f.sky * 1.4) * k -- high over the target and the paw: no zero-length line
			local u = seg(t, 0.35, S.IMPACT)
			if u ~= nil then
				local p = far:Lerp(f.TC, ease(u) ^ 1.6)
				local d = (far - f.TC).Unit
				f.kit:orb(p, 1.0 * k, C.STAR, 9, 1, nil, 4)
				f.kit:spike(p, p + d * 7 * k, 1.0 * k, C.VIOLET, 4, 0.55)
				f.kit:spike(p, p + d * 5 * k, 0.6 * k, C.STAR, 6, 0.7)
				for i = 0, 5 do
					local jitter = f.V(math.sin(i * 3 + t * 20), 0, math.cos(i * 2 + t * 17)) * 0.6 * k
					f.kit:spark(p + d * (1.5 + i) * k + jitter, 0.15 * k, C.WHITE, 9, 1 - i / 6)
				end
			end
			local line = env(t, 0.3, 0.45, 0.8, 0.9)
			if line > 0 then -- it points the way with a thin line of starlight
				f.kit:beam(hand, hand + (far - hand).Unit * 6 * k, 0.05 * k, C.STAR, 7, line)
			end
			u = seg(t, S.IMPACT, 1.55)
			if u ~= nil then
				f.kit:disc(f.T, 3 * k, C.DARK, 0, 0.7 * (1 - u))
				for i = 0, 9 do
					local a = i / 10 * TAU
					local q = f.T
						+ f.V(math.cos(a), math.sin(a), 0) * (1 + 4 * ease(u)) * k
						+ Z(3 * k * math.sin(math.pi * u))
					f.kit:spike(q - Z(0.3 * k), q + Z(0.3 * k), 0.25 * k, C.STAR, 8, 1 - u)
					f.kit:spike(q + Z(0.3 * k), q - Z(0.3 * k), 0.25 * k, C.STAR, 8, 1 - u)
				end
			end
			S.impact(f, C.STAR, 5, 57)
		end,

		-- Abduction Beam: Calls a flying saucer over the target, lifts it up in a green tractor beam, then zaps it back
		-- down.
		creature_meerkat_storm_forge = function(f)
			local k, t = f.k, f.t
			local hover = f.T + Z(f.sky * 0.7)
			local come = seg(t, 0.25, 0.55)
			if t >= 0.25 then
				local p = if come ~= nil then hover + f.V(-8, 6, 4) * k * (1 - ease(come)) else hover
				if t > 1.1 then
					p = hover + f.V(8, -4, 5) * k * ease(math.min(1, (t - 1.1) / 0.35))
				end
				p = p + Z(0.2 * k * math.sin(t * 9))
				-- the saucer: magic.py's squashed sphere (radius 2.6, 1 thick), as a flat beam half as thick, no core
				f.kit:beam(p - Z(0.25 * k), p + Z(0.25 * k), 2.6 * k, Color3.new(0.55, 0.6, 0.66), 0.2, 1.0, false)
				f.kit:orb(p + Z(0.5 * k), 1.0 * k, C.ALIEN, 3, 0.6, false)
				for i = 0, 7 do
					local a = i / 8 * TAU + t * 6
					local col = if i % 2 == 0 then C.ALIEN else C.YELLOW
					f.kit:spark(p + f.V(math.cos(a), math.sin(a), -0.05) * 2.4 * k, 0.22 * k, col, 9, 1)
				end
			end
			local beam = env(t, 0.55, 0.62, 0.86, S.IMPACT)
			if beam > 0 then -- the tractor beam on the target (the concept lifted it; the game cannot)
				f.kit:spike(f.T, hover, 2.0 * k, C.ALIEN, 3, 0.3 * beam)
				f.kit:light(f.TC, C.ALIEN, 5 * beam)
				for i = 0, 4 do
					local v = (t * 1.5 + i / 5) % 1
					f.kit:ring(f.T:Lerp(hover, v), 2.0 * k * (1 - v) + 0.4, 0.06 * k, C.ALIEN, 7, beam * (1 - v))
				end
			end
			local u = seg(t, 0.86, 1.0)
			if u ~= nil then -- and zaps it down (at the unmoved target)
				f.kit:bolt(hover - Z(0.5 * k), f.TC, C.ALIEN, 0.12 * k, 0.12, nil, math.floor(t * 30))
			end
			S.impact(f, C.ALIEN, 4, 59)
		end,
	}
end
