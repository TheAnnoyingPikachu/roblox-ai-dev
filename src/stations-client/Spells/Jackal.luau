--!strict
-- The jackals' spells (magic.py's jackal and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env, bez = S.C, S.Z, S.ease, S.seg, S.env, S.bez
	local TAU = S.TAU

	-- a ghost jackal mid-leap
	local SPIRIT_LEAP = {
		body = { 8, 0, 0, 0, 0.3 },
		leg_fl = { 52 },
		leg_fr = { 48 },
		leg_bl = { -36 },
		leg_br = { -36 },
		tail = { -26 },
		head = { -6 },
	}
	local SPIRIT = Color3.new(0.3, 0.75, 1.0)

	return {
		-- Spirit Pack: howls up two ghostly jackals of blue light, which leap from its sides and tear through the target
		jackal = function(f)
			local k, t = f.k, f.t
			f.kit:aura(C.AQUA, 0.2 * env(t, 0.25, 0.45, 0.8, 0.95))
			for _, side in { 1, -1 } do
				local u = seg(t, 0.45, 1.05)
				if u == nil then
					continue
				end
				local start = f.V(side * 0.35 * f.L, 0.2 * f.L, 0)
				local to = f.T - f.mid
				local finish = Vector3.new(to.X, 0, to.Z) + f.V(side * 0.2 * f.L, -0.15 * f.L, 0)
				local arc = (if side > 0 then 0.75 else 0.2) * f.H
				local ctrl = (start + finish) / 2 + Z(arc)
				local p = bez(start, ctrl, finish, ease(u))
				local fade = env(t, 0.45, 0.55, 0.95, 1.05)
				f.kit:ghost(if side > 0 then "left" else "right", SPIRIT_LEAP, p, SPIRIT, 5, 0.9 * fade, 0.85)
				local tail = {}
				for i = 0, 7 do
					table.insert(tail, f.mid + bez(start, ctrl, finish, ease(math.max(0, u - i * 0.04))))
				end
				f.kit:trail(tail, 0.5 * k, C.AQUA, 4, 0.4 * fade)
			end
			S.impact(f, C.AQUA, 3.5, 5)
			local u = seg(t, S.IMPACT, 1.3)
			if u ~= nil then -- blue spirit flames on the target
				for i = 0, 5 do
					local a = i / 6 * TAU + t * 3
					f.kit:spike(
						f.T + f.V(math.cos(a), math.sin(a), 0) * 0.9 * k,
						f.T
							+ f.V(math.cos(a) * 0.4, math.sin(a) * 0.4, 0) * k
							+ Z((2 + 1.5 * math.sin(i)) * k * (1 - u)),
						0.3 * k,
						C.AQUA,
						6,
						0.7 * (1 - u)
					)
				end
			end
		end,

		-- Judgement of Anubis: Sits like a temple statue; a golden ankh appears over the target, held by a turquoise
		-- beam from its brow gem, then slams down; glyphs rise round the target.
		creature_jackal_pharaoh_forge = function(f)
			local k, t = f.k, f.t
			f.kit:aura(C.TURQ, 0.25 * env(t, 0.25, 0.45, 0.82, 0.92))
			local top = f.T + Z(f.sky * 0.55)
			local form = env(t, 0.3, 0.75, 2, 3)
			local u = seg(t, 0.84, S.IMPACT)
			local p = if u == nil then top else top:Lerp(f.T + Z(2.2 * k), ease(u))
			if t < S.IMPACT + 0.01 and form > 0 then -- a golden ankh in the sky, then down like a hammer
				local s = 1.4 * k
				f.kit:ring(p + Z(1.1 * s), 0.6 * s, 0.13 * s, C.GOLD, 8, form, f.V(1, 0, 0))
				f.kit:tube({ p + Z(0.55 * s), p - Z(1.8 * s) }, 0.15 * s, C.GOLD, 8, form)
				f.kit:tube({ p + f.V(0, -1.0, 0) * s, p + f.V(0, 1.0, 0) * s }, 0.15 * s, C.GOLD, 8, form)
				f.kit:orb(p + Z(1.1 * s), 0.3 * s, C.TURQ, 8, form)
				f.kit:light(p, C.GOLD, 4 * form)
			end
			local beam = env(t, 0.5, 0.6, 0.84, 0.9)
			if beam > 0 then -- its brow gem holds a turquoise beam on the ankh
				f.kit:beam(f.A.crown, p + Z(1.5 * k), 0.12 * k, C.TURQ, 8, beam)
			end
			u = seg(t, S.IMPACT, 1.5)
			if u ~= nil then
				for i = 0, 9 do -- a ring of glyphs rising off the ground
					local a = i / 10 * TAU + t
					local q = f.T + f.V(math.cos(a), math.sin(a), 0) * 2.8 * k + Z(1.5 * k * u)
					f.kit:box(q, { 0.4 * k, 0.1 * k, 0.6 * k }, if i % 2 ~= 0 then C.GOLD else C.TURQ, 6, 1 - u)
				end
			end
			S.impact(f, C.TURQ, 4, 41)
		end,

		-- Sandstorm Riddle: The sun disc between its ears blazes as a sandstorm with golden glyphs whirls round the
		-- target, then the disc fires a beam of sunlight into it.
		creature_jackal_sphinx_forge = function(f)
			local k, t = f.k, f.t
			local disc = env(t, 0.2, 0.5, 0.95, 1.1)
			if disc > 0 then
				f.kit:orb(f.A.crown + Z(0.4 * k), 0.55 * k, C.SUN, 8, disc, nil, 3 * disc)
			end
			local storm = env(t, 0.4, 0.8, 1.15, 1.5)
			if storm > 0 then
				f.kit:vortex(f.T, 2.6 * k, 6 * k * storm, C.SAND, t, 6, 1.5, 0.6 * storm, nil, 0.25)
				for i = 0, 7 do
					local a = -t * 5 + i / 8 * TAU
					local q = f.T + f.V(math.cos(a), math.sin(a), 0) * 3.2 * k + Z((1 + 0.5 * math.sin(a * 2)) * k)
					f.kit:box(q, { 0.35 * k, 0.08 * k, 0.5 * k }, C.GOLD, 7, storm)
				end
				f.kit:burst(f.T + Z(1.5 * k), (t * 1.5) % 1, 12, 3 * k, C.SAND, 43, 0.12 * k, nil, 1)
			end
			local u = seg(t, 0.86, 1.2)
			if u ~= nil then
				local reach = ease(math.min(1, (t - 0.86) / (S.IMPACT - 0.86)))
				local a = f.A.crown + Z(0.4 * k)
				f.kit:beam(a, a:Lerp(f.TC, reach), 0.35 * k * (1 - u * 0.7), C.SUN, 9, 1)
			end
			S.impact(f, C.SUN, 4, 45)
		end,
	}
end
