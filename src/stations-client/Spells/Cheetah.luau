--!strict
-- The cheetahs' spells (magic.py's cheetah and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env = S.C, S.Z, S.ease, S.seg, S.env

	return {
		-- Wind Blades: two quick swipes send crescents of wind at the target, then a double swipe sends a big one at the
		-- impact
		cheetah = function(f)
			local k, t = f.k, f.t
			local blades = {
				{ t0 = 0.5, paw = "paw_r", tilt = 0.6 },
				{ t0 = 0.7, paw = "paw_l", tilt = -0.6 },
				{ t0 = 0.86, paw = "paw_l", tilt = 0.0 },
			}
			for n, blade in blades do
				local i, t0, tilt = n - 1, blade.t0, blade.tilt
				local big = if i == 2 then 1.7 else 1.0
				local t1 = t0 + (if i < 2 then 0.18 else S.IMPACT - 0.86 + 0.0001)
				local a = f.mid + f.V(0, -0.45 * f.L, 0.1 * f.H)
				local u = seg(t, t0, t1)
				if u ~= nil then
					local p = a:Lerp(f.TC, ease(u))
					f.kit:crescent(
						p,
						1.3 * big * k,
						0.13 * big * k,
						C.MINT,
						f.V(math.sin(tilt), 0, math.cos(tilt)),
						f.V(0, -1, 0),
						7
					)
					local pts = {}
					for j = 0, 5 do
						table.insert(pts, a:Lerp(f.TC, ease(math.max(0, u - j * 0.08))))
					end
					f.kit:trail(pts, 0.45 * big * k, C.MINT, 2, 0.2)
				end
				local h = seg(t, t1, t1 + 0.3)
				if h ~= nil then -- a slash mark on the target
					local d = if i < 2 then f.V(0.7, 0, if i ~= 1 then 0.7 else -0.7).Unit else f.V(1, 0, 0)
					f.kit:tube(
						{
							f.TC - d * 1.6 * big * k + f.V(0, -0.4, 0),
							f.TC + d * 1.6 * big * k + f.V(0, -0.4, 0),
						},
						0.1 * big * k,
						C.WHITE,
						9,
						1 - h,
						nil,
						function(x: number)
							return math.sin(math.pi * x)
						end
					)
				end
			end
			S.impact(f, C.MINT, 3, 15, nil, false)
		end,

		-- Chain Lightning: lightning crackles at its tail tip, then a bolt leaps to the target and chains on to two more
		-- behind it
		creature_cheetah_lightning_forge = function(f)
			local k, t = f.k, f.t
			local tail = f.A.tail
			f.kit:aura(C.YELLOW, 0.15 * env(t, 0.25, 0.4, 0.86, 0.95), 6)
			if 0.3 <= t and t <= 0.86 then -- crackling at the tail tip
				for j = 0, 1 do
					f.kit:bolt(
						tail,
						tail + f.V(math.sin(t * 40 + j), math.cos(t * 33 + j), 0.8) * 1.2 * k,
						C.YELLOW,
						0.05 * k,
						0.25,
						4,
						math.floor(t * 24) + j
					)
				end
				f.kit:orb(tail, 0.35 * k, C.YELLOW, 8, 1, nil, 2)
			end
			local apex = f.mid + f.V(0, -0.2 * f.L, 1.3 * f.H)
			local hops = {
				{ t0 = 0.84, a = tail, b = apex },
				{ t0 = 0.86, a = apex, b = f.TC },
				{ t0 = S.IMPACT + 0.06, a = f.TC, b = f.T + f.V(3.5, -4, 0) * k },
				{ t0 = S.IMPACT + 0.14, a = f.T + f.V(3.5, -4, 0) * k, b = f.T + f.V(-3.5, -6, 0) * k },
			}
			for n, hop in hops do
				local i, t0, a, b = n - 1, hop.t0, hop.a, hop.b
				local u = seg(t, t0, t0 + 0.2)
				if u ~= nil then
					f.kit:bolt(a, b, C.YELLOW, 0.13 * k, 0.12, nil, math.floor(t * 30) + i, nil, 1 - u * 0.5, 2)
					f.kit:light(b, C.YELLOW, 6)
				end
				if i > 1 then
					local h = seg(t, t0, t0 + 0.4)
					if h ~= nil then
						f.kit:ring(b + Z(0.1), (0.4 + 2 * h) * k, 0.1 * k, C.YELLOW, 7, 1 - h)
						f.kit:burst(b, h, 8, 2 * k, C.YELLOW, 61 + i, 0.12 * k)
					end
				end
			end
			S.impact(f, C.YELLOW, 3.5, 63)
		end,

		-- Thunderhead: a storm cloud boils up over its back, drifts over the target and hammers it with three bolts and a
		-- thunderclap
		creature_cheetah_thunder_forge = function(f)
			local k, t = f.k, f.t
			local start = f.mid + Z(f.H * 0.9)
			local over = f.T + Z(f.sky * 0.65)
			local g = env(t, 0.15, 0.5, 1.2, 1.55)
			if g > 0 then
				local u = seg(t, 0.5, 0.82)
				local p = if t < 0.5 then start elseif u ~= nil then start:Lerp(over, ease(u)) else over
				f.kit:cloud(p, 2.6 * k * g, Color3.new(0.42, 0.36, 0.75), 3, 0.95, 0.6)
				if math.floor(t * 20) % 3 == 0 then -- flickers inside it
					f.kit:light(p, C.STORM, 8 * g)
				end
				if t > 0.86 then
					for i = 0, 13 do -- rain
						local q = p
							+ f.V((i % 5 - 2) * 1.0, (i // 5 - 1) * 1.0, -1.5) * k
							- Z(((t * 6 + i * 0.37) % 1) * (f.sky * 0.6))
						f.kit:tube({ q, q - Z(0.8 * k) }, 0.04 * k, Color3.new(0.7, 0.75, 1.0), 2, 0.6 * g)
					end
				end
			end
			for i = 0, 2 do
				local u = seg(t, 0.86 + i * 0.05, 0.98 + i * 0.05)
				if u ~= nil then
					local finish = f.TC + f.V((i - 1) * 0.6, 0, (1 - i) * 0.4) * k
					f.kit:bolt(
						over - Z(1.5 * k),
						finish,
						C.STORM,
						0.16 * k,
						0.1,
						nil,
						i * 5 + math.floor(t * 25),
						nil,
						nil,
						2
					)
					f.kit:light(finish, C.STORM, 8)
				end
			end
			local u = seg(t, S.IMPACT, 1.4)
			if u ~= nil then -- the thunderclap
				for j = 0, 1 do
					f.kit:ring(f.T + Z(0.2 + 1.2 * j), (0.8 + 5 * ease(u)) * k, 0.12 * k, C.STORM, 7, 1 - u)
				end
			end
			S.impact(f, C.STORM, 3, 65)
		end,
	}
end
