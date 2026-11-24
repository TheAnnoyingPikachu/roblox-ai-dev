--!strict
-- The rhinos' spells (magic.py's rhino and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env = S.C, S.Z, S.ease, S.seg, S.env
	local TAU = S.TAU

	-- mathutils' normalized(): a zero vector stays zero
	local function unit(v: Vector3): Vector3
		return if v.Magnitude > 1e-6 then v.Unit else v
	end

	return {
		-- Horn Lance: lowers its head while light gathers on its horn, then fires an amber beam from the horn into the
		-- target
		rhino = function(f)
			local k, t = f.k, f.t
			local horn = f.A.horn
			local charge = env(t, 0.2, 0.8, 0.86, 0.9)
			if charge > 0 then
				f.kit:orb(horn, 0.5 * k * charge, C.AMBER, 8, 1, nil, 3 * charge)
				for i = 0, 5 do -- motes drawn in to the horn
					local a = i / 6 * TAU + t * 3
					local v = (t * 2 + i / 6) % 1
					f.kit:spark(horn + f.V(math.cos(a), -0.5, math.sin(a)) * (1 - v) * 2.2 * k, 0.1 * k, C.AMBER, 8, v)
				end
			end
			local u = seg(t, 0.86, 1.2)
			if u ~= nil then
				local reach = ease(math.min(1, (t - 0.86) / (S.IMPACT - 0.86)))
				local w = 0.55 * k * (1 - ease(math.max(0, (t - 1.0) / 0.2)))
				local finish = horn:Lerp(f.TC, reach)
				f.kit:beam(horn, finish, w, C.AMBER, 8, 1)
				for i = 0, 3 do -- rings spiralling along the beam
					local v = (t * 3 + i / 4) % 1 * reach
					f.kit:ring(horn:Lerp(f.TC, v), 0.9 * k, 0.06 * k, C.AMBER, 6, 0.8, f.TC - horn)
				end
				f.kit:light(finish, C.AMBER, 6)
			end
			S.impact(f, C.AMBER, 3.5, 19)
		end,

		-- Magma Eruption: rears and slams; lava cracks race to the target, a pool of lava opens under it and erupts,
		-- throwing up molten rocks
		creature_rhino_lava_forge = function(f)
			local k, t = f.k, f.t
			local base = S.ground(f, f.A.chest)
			local u = seg(t, 0.82, S.IMPACT)
			local reach = if t > S.IMPACT then 1.0 elseif u ~= nil then ease(u) else 0
			if t >= 0.82 then -- lava cracks race to the target
				local fade = 1 - ease(math.max(0, (t - 1.2) / 0.3))
				for _, j in { -1, 1, 0 } do
					local pts = {}
					for s = 0, 8 do
						table.insert(
							pts,
							base:Lerp(f.T + f.V(j * 1.2, 0, 0) * k, reach * s / 8)
								+ f.V(0.35 * math.sin(s * 2.1 + j), 0, 0.05) * k
						)
					end
					f.kit:tube(pts, 0.16 * k, C.LAVA, 8, fade)
				end
			end
			local pool = env(t, 0.88, S.IMPACT, 1.25, 1.5)
			if pool > 0 then
				f.kit:disc(f.T, 1.8 * k * pool, Color3.new(0.9, 0.18, 0.02), 3, 0.9 * pool)
			end
			u = seg(t, S.IMPACT, 1.55)
			if u ~= nil then -- the eruption
				local h = 6 * k * ease(math.min(1, u * 3)) * (1 - ease(math.max(0, (u - 0.5) / 0.5)))
				f.kit:spike(f.T, f.T + Z(h), 1.5 * k, C.FIRE, 6, 0.85)
				f.kit:spike(f.T, f.T + Z(h * 0.8), 0.8 * k, C.YELLOW, 8, 0.9)
				f.kit:light(f.TC, C.LAVA, 10 * (1 - u))
				for i = 0, 6 do -- molten rocks thrown up
					local a = i / 7 * TAU + 0.5
					local d = f.V(math.cos(a), math.sin(a), 0)
					local q = f.T + d * 4 * k * u + Z(6 * k * u - 7 * k * u * u + 1 * k)
					f.kit:ball(q, 0.4 * k, Color3.new(0.12, 0.05, 0.04), 0)
					f.kit:orb(q, 0.45 * k, C.LAVA, 6, 0.6, false)
				end
			end
			S.impact(f, C.LAVA, 3.5, 67, nil, false)
		end,

		-- Prism Beam: seven coloured lights circle into its crystal horn, then it fires a white beam wound with all seven
		-- colours; crystals of each colour burst from the target
		creature_rhino_crystal_forge = function(f)
			local k, t = f.k, f.t
			local horn = f.A.horn
			local c = env(t, 0.2, 0.75, 0.86, 0.92)
			if c > 0 then
				for n, rgb in S.RAINBOW do -- seven motes circling in to the horn
					local i = n - 1
					local a = t * 6 + i / 7 * TAU
					local rr = (1 - ease(seg(t, 0.2, 0.86) or 1)) * 2.5 * k + 0.4 * k
					f.kit:orb(horn + f.V(math.cos(a), math.sin(a) * 0.4, math.sin(a)) * rr, 0.25 * k, rgb, 8, c, false)
				end
				f.kit:orb(horn, 0.45 * k * c, C.WHITE, 9, c, nil, 3 * c)
			end
			local u = seg(t, 0.86, 1.2)
			if u ~= nil then
				local reach = ease(math.min(1, (t - 0.86) / (S.IMPACT - 0.86)))
				local finish = horn:Lerp(f.TC, reach)
				local fade = 1 - ease(math.max(0, (t - 1.02) / 0.18))
				f.kit:beam(horn, finish, 0.18 * k, C.WHITE, 9, fade, false)
				local d = unit(f.TC - horn)
				local side = unit(d:Cross(f.V(0, 0, 1)))
				local up = side:Cross(d)
				for n, rgb in S.RAINBOW do -- the colours twisting round it
					local i = n - 1
					local a = i / 7 * TAU + t * 10
					local off = (side * math.cos(a) + up * math.sin(a)) * 0.6 * k
					f.kit:beam(horn + off * 0.3, finish + off, 0.15 * k, rgb, 7, fade, false)
				end
			end
			u = seg(t, S.IMPACT, 1.5)
			if u ~= nil then -- crystals of seven colours burst out round it
				for n, rgb in S.RAINBOW do
					local i = n - 1
					local a = i / 7 * TAU + 0.2
					local d = f.V(math.cos(a), math.sin(a), 0.7).Unit
					local g = ease(math.min(1, u * 5)) * (1 - ease(math.max(0, (u - 0.65) / 0.35)))
					f.kit:diamond(f.T + d * 1.4 * k + Z(0.5 * k), 0.55 * k * g, 2.4 * k * g, rgb, 6, 1, nil, d)
				end
			end
			S.impact(f, C.WHITE, 4, 69)
		end,

		-- Sunfire Horn (the Molten Sun Rhino): its horn takes fire as molten cracks glow under it; a crack races to the
		-- target with sun spikes bursting along it, its horn fires, and a pillar of molten sun erupts
		creature_rhino_sahara_forge = function(f)
			local k, t = f.k, f.t
			local horn = f.A.horn
			local feet = S.ground(f, (f.A.paw_l + f.A.paw_r) / 2)
			local g = env(t, 0.15, 0.7, 0.9, 1.05)
			if g > 0 then
				f.kit:orb(horn, 0.6 * k * g, C.SUN, 9, g, nil, 4 * g)
				f.kit:disc(feet, 2.2 * k * g, C.LAVA, 3, 0.5 * g)
			end
			local u = seg(t, 0.8, 1.25)
			if u ~= nil then
				local run = ease(math.min(1, (t - 0.8) / (S.IMPACT - 0.8)))
				local fade = 1 - ease(math.max(0, (t - 1.05) / 0.2))
				f.kit:beam(feet + Z(0.05), feet:Lerp(f.T, run) + Z(0.05), 0.25 * k, C.LAVA, 8, fade)
				for i = 0, 6 do
					local v = (i + 1) / 8
					if v <= run then
						local p = feet:Lerp(f.T, v)
						f.kit:spike(
							p,
							p + Z((0.8 + 2.2 * v) * k * fade),
							0.4 * k,
							if i % 2 == 1 then C.SUN else C.LAVA,
							8,
							fade
						)
					end
				end
				f.kit:beam(horn, horn:Lerp(f.TC, run), 0.4 * k, C.SUN, 10, fade)
			end
			u = seg(t, S.IMPACT, 1.5)
			if u ~= nil then
				local rise = ease(math.min(1, u * 4)) * (1 - ease(math.max(0, (u - 0.5) / 0.5)))
				f.kit:beam(f.T, f.T + Z(9 * k * rise), 1.3 * k, C.LAVA, 8, rise)
				f.kit:beam(f.T, f.T + Z(9 * k * rise), 0.7 * k, C.YELLOW, 10, rise)
				f.kit:shock(f.T + Z(0.08), (1 + 6 * ease(u)) * k, 0.1 * k, C.SUN, 1 - u)
			end
			S.impact(f, C.SUN, 5, 96)
		end,
	}
end
