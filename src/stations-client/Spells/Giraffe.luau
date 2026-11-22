--!strict
-- The giraffes' spells (magic.py's giraffe and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env, bez = S.C, S.Z, S.ease, S.seg, S.env, S.bez
	local TAU = S.TAU

	return {
		-- Sky Lance: points its head at the sky; a great spear of light forms high over the target and plunges into it
		giraffe = function(f)
			local k, t = f.k, f.t
			local crown = f.A.crown
			local up = env(t, 0.3, 0.45, 0.8, 0.9)
			if up > 0 then
				f.kit:beam(crown, crown + Z(f.sky * 1.2), 0.1 * k, C.LAV, 6, up)
			end
			local top = f.T + Z(f.sky)
			local form = env(t, 0.4, 0.82, 2, 3)
			if t < 0.86 and form > 0 then
				f.kit:spike(top + Z(2.5 * k), top - Z(3.5 * k * form), 0.7 * k * form, C.WHITE, 9, form)
				f.kit:orb(top + Z(2.5 * k), 1.2 * k * form, C.LAV, 5, 0.6 * form, false)
				f.kit:ring(top, 2.4 * k * form, 0.1 * k, C.LAV, 6, form)
			end
			local u = seg(t, 0.86, S.IMPACT)
			if u ~= nil then
				local tip = top:Lerp(f.T + Z(0.6 * k), ease(u))
				f.kit:spike(tip + Z(6 * k), tip, 0.7 * k, C.WHITE, 10, 1)
				local pts = {}
				for i = 0, 4 do
					table.insert(pts, tip + Z((6 + 2 * i) * k))
				end
				f.kit:trail(pts, 1.4 * k, C.LAV, 4, 0.5)
			end
			u = seg(t, S.IMPACT, 1.45)
			if u ~= nil then
				f.kit:spike(f.T + Z(6 * k), f.T - Z(0.5 * k), 0.7 * k, C.WHITE, 9, 1 - u)
				for i = 0, 5 do -- shards kicked up
					local a = i / 6 * TAU
					local q = f.T
						+ f.V(math.cos(a), math.sin(a), 0) * (1 + 2 * u) * k
						+ Z(2.5 * k * math.sin(math.pi * math.min(1, u * 1.5)))
					f.kit:diamond(q, 0.25 * k, 0.6 * k, C.LAV, 6, 1 - u, t * 8)
				end
			end
			S.impact(f, C.LAV, 4, 35)
		end,

		-- Thorn Grove: stamps; roots burrow to the target and thorny acacia branches erupt all round it, leaves flying
		creature_giraffe_acacia_forge = function(f)
			local k, t = f.k, f.t
			local feet = S.ground(f, (f.A.paw_l + f.A.paw_r) / 2)
			local u = seg(t, 0.45, 0.9)
			if u ~= nil or t > 0.9 then -- roots burrow along under the ground, leaves sparkling where they pass
				local reach = if u ~= nil then ease(u) else 1.0
				local fade = 1 - ease(math.max(0, (t - 1.2) / 0.3))
				for _, j in { -1, 1 } do
					local pts = {}
					for s = 0, 8 do
						table.insert(
							pts,
							feet:Lerp(f.T, reach * s / 8) + f.V(j * (0.5 + 0.4 * math.sin(s * 1.7)), 0, 0.08) * k
						)
					end
					f.kit:tube(pts, 0.18 * k, Color3.new(0.35, 0.22, 0.1), 0, fade)
				end
				f.kit:spark(feet:Lerp(f.T, reach) + Z(0.3 * k), 0.25 * k, C.LEAF, 7, fade)
			end
			u = seg(t, 0.88, 1.55)
			if u ~= nil then -- thorny branches erupt round it
				local g = ease(math.min(1, u * 4)) * (1 - ease(math.max(0, (u - 0.65) / 0.35)))
				local function taper(x: number): number
					return 1 - 0.7 * x
				end
				for i = 0, 5 do
					local a = i / 6 * TAU + 0.2
					local d = f.V(math.cos(a), math.sin(a), 0)
					local b = f.T + d * 2.0 * k
					local pts = {}
					for s = 0, 5 do
						table.insert(pts, b + (d * -0.8 * s / 5 + Z(3.5 * s / 5) + d * 0.4 * math.sin(s)) * k * g)
					end
					f.kit:tube(pts, 0.22 * k, Color3.new(0.35, 0.22, 0.1), 0.2, 1, nil, taper)
					for _, s in { 2, 3, 4 } do
						local q = pts[s + 1]
						f.kit:spike(q, q + (d + Z(0.5)).Unit * 0.8 * k * g, 0.1 * k, Color3.new(0.95, 0.9, 0.7), 1, 1)
					end
					f.kit:ball(pts[#pts], 0.55 * k * g, C.LEAF, 1.5, 1)
				end
				f.kit:burst(f.TC, u, 16, 4 * k, C.LEAF, 81, 0.18 * k, nil, 4)
			end
			S.impact(f, C.LEAF, 3, 83, nil, false)
		end,

		-- Diamond Prison: its horns flash and throw a diamond over the target; diamond pillars slam down round it into a
		-- cage, then shatter
		creature_giraffe_diamond_forge = function(f)
			local k, t = f.k, f.t
			local crown = f.A.crown
			local g = env(t, 0.25, 0.65, 0.8, 0.88)
			if g > 0 then
				f.kit:orb(crown, 0.6 * k * g, C.DIAMOND, 9, g, nil, 3 * g)
			end
			local u = seg(t, 0.62, 0.84)
			if u ~= nil then -- a shard of light arcs over to the target
				local p = bez(crown, (crown + f.TC) / 2 + Z(4 * k), f.TC + Z(4 * k), ease(u))
				f.kit:diamond(p, 0.4 * k, 1.2 * k, C.DIAMOND, 9, 1, t * 10)
			end
			u = seg(t, 0.82, 1.55)
			if u ~= nil then -- diamond pillars slam down round it into a cage, then shatter
				local close = ease(math.min(1, (t - 0.82) / (S.IMPACT - 0.82)))
				local shatter = seg(t, 1.15, 1.55)
				for i = 0, 5 do
					local a = i / 6 * TAU
					local d = f.V(math.cos(a), math.sin(a), 0)
					if shatter == nil then
						local p = f.T + d * (2.0 - 0.6 * close) * k + Z((2.2 + 6 * (1 - close)) * k)
						f.kit:diamond(p, 0.5 * k, 4.6 * k, C.DIAMOND, 6, 0.85, a)
					else
						for j = 0, 2 do
							local q = f.T
								+ d * (1.4 + 3 * shatter) * k
								+ Z((1 + j * 1.4) * k + 2 * k * shatter - 3 * k * shatter * shatter)
							f.kit:diamond(q, 0.3 * k, 0.8 * k, C.DIAMOND, 7, 1 - shatter, t * 9 + j)
						end
					end
				end
				if shatter == nil and t >= S.IMPACT then
					f.kit:ring(f.T + Z(4.4 * k), 1.6 * k, 0.12 * k, C.WHITE, 8, 1)
				end
			end
			S.impact(f, C.DIAMOND, 3.5, 85)
		end,
	}
end
