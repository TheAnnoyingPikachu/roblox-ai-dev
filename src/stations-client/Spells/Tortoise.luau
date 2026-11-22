--!strict
-- The tortoises' spells (magic.py's tortoise and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env, bez = S.C, S.Z, S.ease, S.seg, S.env, S.bez
	local TAU = S.TAU

	return {
		-- Shell Nova: Pulls into its shell over a spinning jade rune circle, glowing brighter, then bursts in a dome of
		-- jade light that rolls out over the target.
		tortoise = function(f)
			local k, t = f.k, f.t
			local charge = env(t, 0.2, 0.85, 0.92, 1.0)
			f.kit:aura(C.JADE, if 0.2 < t and t < 1.0 then 0.15 + 0.35 * charge else 0.0, 4 + 6 * charge)
			local under = S.ground(f, f.mid)
			if charge > 0 then
				f.kit:circle(under, 0.75 * f.L * charge, C.JADE, t * 2, 6, charge)
			end
			local u = seg(t, S.IMPACT, S.IMPACT + 0.45)
			if u ~= nil then
				local reach = (under - f.T).Magnitude + 2 * k
				local R = 0.4 * f.L + reach * ease(u)
				f.kit:orb(f.mid, R, C.JADE, 2, 0.1 * (1 - u), false)
				f.kit:ring(under + Z(0.1), R, 0.2 * k, C.JADE, 7, 1 - u)
				f.kit:light(f.mid, C.JADE, 10 * (1 - u))
			end
			local hit = seg(t, S.IMPACT + 0.12, S.IMPACT + 0.6)
			if hit ~= nil then
				f.kit:orb(f.TC, (0.6 + 1.2 * ease(hit)) * k, C.JADE, 7, 0.8 * (1 - hit))
				f.kit:burst(f.TC, hit, 14, 3 * k, C.JADE, 9, 0.14 * k)
			end
		end,

		-- Gem Barrage: Six glowing gems lift off its shell and hover, then fire at the target one after another and
		-- shatter on it.
		creature_tortoise_gemshell_forge = function(f)
			local k, t = f.k, f.t
			local back = f.A.back
			local cols = { C.ROSE, C.TURQ, Color3.new(0.9, 0.3, 1.0), C.GOLD, C.ROSE, C.TURQ }
			for i = 0, 5 do
				local col = cols[i + 1]
				local rise = seg(t, 0.2 + i * 0.04, 0.55 + i * 0.04)
				local holdAt = back + f.V(0.3, (i - 2.5) * 0.9, 1.8 + 0.4 * math.sin(i)) * k
				local t0 = 0.6 + i * 0.054
				if t < t0 then
					if rise ~= nil or t > 0.55 + i * 0.04 then
						local p = back:Lerp(holdAt, ease(if rise ~= nil then rise else 1))
						f.kit:diamond(p, 0.35 * k, 0.9 * k, col, 6, 1, t * 6 + i)
						f.kit:light(p, col, 1)
					end
					continue
				end
				local u = seg(t, t0, t0 + 0.2)
				if u ~= nil then
					local finish = f.TC + f.V(0, (i - 2.5) * 0.3, (i % 3 - 1) * 0.6) * k
					local ctrl = (holdAt + finish) / 2 + Z(2 * k)
					local p = bez(holdAt, ctrl, finish, u)
					f.kit:diamond(p, 0.35 * k, 0.9 * k, col, 8, 1, t * 12, finish - holdAt)
					local tail = {}
					for m = 0, 4 do
						table.insert(tail, bez(holdAt, ctrl, finish, math.max(0, u - m * 0.06)))
					end
					f.kit:trail(tail, 0.3 * k, col, 4, 0.5)
				end
				local h = seg(t, t0 + 0.2, t0 + 0.55)
				if h ~= nil then
					f.kit:burst(f.TC, h, 8, 2 * k, col, 47 + i, 0.14 * k)
				end
			end
			S.impact(f, C.ROSE, 3.5, 49, nil, true)
		end,

		-- Island Surge: Rears and stamps; a wave rises before it and rolls over the target, and vines and glowing
		-- flowers spring up round it.
		creature_tortoise_island_forge = function(f)
			local k, t = f.k, f.t
			local start = S.ground(f, f.A.chest) + f.V(0, -1.0, 0) * k
			local rise = seg(t, 0.45, 0.82)
			local roll = seg(t, 0.82, S.IMPACT + 0.06)
			if rise ~= nil or roll ~= nil then
				local p = if roll == nil then start else start:Lerp(f.T, ease(roll))
				local h = 4 * k * (if rise ~= nil then ease(rise) else 1)
				local fwd = f.V(0, -1, 0)
				local R = h / 2
				for j = 0, 4 do -- a curling wall of water across its path: bottom, up the back, over the top
					local c = p + f.V((j - 2) * 1.0 * k, 0, 0) + Z(R)
					local pts = {}
					for x = 0, 14 do
						local a = x / 14 * 1.3 * math.pi
						table.insert(pts, c - fwd * R * math.sin(a) - Z(R * math.cos(a)))
					end
					f.kit:tube(pts, 0.55 * k, C.SEA, 2, 0.6, nil, function(x: number)
						return 1.2 - 0.9 * x
					end)
					f.kit:spark(pts[#pts], 0.3 * k, Color3.new(0.9, 0.97, 1), 3, 0.9)
				end
				f.kit:burst(
					p + Z(h) + fwd * R * 0.6,
					(t * 2) % 1,
					8,
					1.2 * k,
					Color3.new(0.9, 0.97, 1),
					51,
					0.18 * k,
					nil,
					2
				)
			end
			local u = seg(t, S.IMPACT, 1.5)
			if u ~= nil then
				f.kit:burst(f.TC, u, 22, 4 * k, C.AQUA, 53, 0.22 * k, nil, 3)
				f.kit:disc(f.T, 3 * k * math.min(1, u * 3), C.SEA, 1.5, 0.5 * (1 - u))
				local g = if u > 0.15 then ease(math.min(1, (u - 0.15) * 3)) else 0
				for i = 0, 5 do -- vines and glowing flowers spring up round it
					local a = i / 6 * TAU + 0.3
					local b = f.T + f.V(math.cos(a), math.sin(a), 0) * 1.6 * k
					local tip = b + Z(2.8 * k * g) - f.V(math.cos(a), math.sin(a), 0) * 0.9 * k * g
					if g > 0 then
						local bend = f.V(math.cos(a + 1), math.sin(a + 1), 0) * 0.4 * k
						f.kit:tube({ b, b:Lerp(tip, 0.5) + bend, tip }, 0.12 * k, C.LEAF, 1, 1)
						f.kit:orb(tip, 0.35 * k * g, if i % 2 == 0 then C.PINK else C.STAR, 7, 1, false)
					end
				end
			end
			S.impact(f, C.AQUA, 3.5, 55, nil, false)
		end,
	}
end
