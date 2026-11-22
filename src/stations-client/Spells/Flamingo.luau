--!strict
-- The flamingos' spells (magic.py's flamingo and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env, bez = S.C, S.Z, S.ease, S.seg, S.env, S.bez
	local TAU = S.TAU

	-- a ghost flamingo diving, wings spread
	local FIREBIRD = {
		leg_bl = { 0, 0, 80 },
		leg_br = { 0, 0, -80 },
		body = { -20, 0, 0, 0, 0.2, 0 },
		head = { -10 },
		leg_fl = { -30 },
		leg_fr = { -30 },
		tail = { -10 },
	}

	-- mathutils' normalized(): a zero vector stays zero
	local function unit(v: Vector3): Vector3
		return if v.Magnitude > 1e-6 then v.Unit else v
	end

	return {
		-- Feather Darts: spreads its wings as glowing pink feathers form along them, then sweeps them forward and fires
		-- the feathers in a volley
		flamingo = function(f)
			local k, t = f.k, f.t
			for i = 0, 7 do
				local wing = if i % 2 == 0 then "wing_l" else "wing_r"
				local side = if i % 2 == 0 then 1 else -1
				local j = i // 2
				local show = env(t, 0.25 + j * 0.06, 0.4 + j * 0.06, 2, 3)
				local t0 = 0.72 + j * 0.03
				local held = f.A[wing] + f.V(side * -0.3 * j, 0.2 * j, 0.3 * j) * k
				if t < t0 and show > 0 then
					f.kit:spike(held, held + f.V(0, -1.1, 0.2) * k, 0.18 * k, C.PINK, 7, show)
				end
				local u = seg(t, t0, t0 + 0.18)
				if u ~= nil then
					local ctrl = (held + f.TC) / 2 + Z(1.5 * k)
					local p = bez(held, ctrl, f.TC + f.V(side * 0.3 * j, 0, 0.4 * j - 0.6) * k, u)
					local q = bez(held, ctrl, f.TC, math.min(1, u + 0.05))
					f.kit:spike(p - unit(q - p) * 0.9 * k, p + unit(q - p) * 0.4 * k, 0.17 * k, C.PINK, 8, 1)
					local pts = {}
					for m = 0, 4 do
						table.insert(pts, bez(held, ctrl, f.TC, math.max(0, u - m * 0.05)))
					end
					f.kit:trail(pts, 0.25 * k, C.PINK, 3, 0.5)
				end
				local h = seg(t, t0 + 0.18, t0 + 0.5)
				if h ~= nil then
					f.kit:spark(
						f.TC + f.V(side * 0.3 * j, -0.5, 0.4 * j - 0.6) * k,
						0.25 * k * (1 - h),
						C.WHITE,
						9,
						1 - h
					)
				end
			end
			S.impact(f, C.PINK, 3, 23)
		end,

		-- Royal Fan: raises its great fan; every eye spot lights up, then they all fire beams into the target and a crown
		-- of light forms over it
		creature_flamingo_peacock_forge = function(f)
			local k, t = f.k, f.t
			local tail = f.A.tail
			local behind = tail + f.V(0, 0.6, 1.2) * k
			local show = env(t, 0.2, 0.55, 0.95, 1.15)
			local hues = { C.TURQ, C.GOLD, C.SEA }
			local eyes = {}
			for i = 0, 8 do -- eye spots glow in a fan behind it
				local a = math.pi * (0.15 + 0.7 * i / 8)
				local q = behind + (f.V(0.5, 0.85, 0) * math.cos(a) * 3.2 + f.V(0, 0.3, 0) + Z(math.sin(a) * 2.6)) * k
				table.insert(eyes, q)
				if show > 0 then
					f.kit:orb(q, 0.4 * k * show, hues[i % 3 + 1], 8, show)
				end
			end
			if show > 0 then
				f.kit:light(behind, C.TURQ, 4 * show)
			end
			for n, q in eyes do
				local i = n - 1
				local u = seg(t, 0.8 + i * 0.012, 1.15)
				if u ~= nil then
					local reach = ease(math.min(1, (t - 0.8 - i * 0.012) / 0.1))
					f.kit:beam(
						q,
						q:Lerp(f.TC, reach),
						0.08 * k,
						hues[i % 3 + 1],
						8,
						1 - ease(math.max(0, (t - 1.0) / 0.15)),
						false
					)
				end
			end
			local u = seg(t, S.IMPACT, 1.5)
			if u ~= nil then -- a crown of light over the target
				local p = f.TC + Z((2.2 + 0.8 * u) * k)
				f.kit:ring(p, 1.2 * k, 0.12 * k, C.GOLD, 8, 1 - u)
				for i = 0, 4 do
					local a = i / 5 * TAU
					local b = p + f.V(math.cos(a), math.sin(a), 0) * 1.2 * k
					f.kit:spike(b, b + Z(0.9 * k), 0.2 * k, C.GOLD, 8, 1 - u)
				end
			end
			S.impact(f, C.TURQ, 3.5, 71)
		end,

		-- Firebird: wreathed in flames, it spreads its wings and sends a giant bird of fire diving onto the target, which
		-- bursts in a ring of fire
		creature_flamingo_phoenix_forge = function(f)
			local k, t = f.k, f.t
			f.kit:aura(C.FIRE, 0.3 * env(t, 0.2, 0.5, 0.75, 0.9), 7)
			for i = 0, 4 do -- flames licking up round it
				local v = (t * 2 + i / 5) % 1
				local a = i / 5 * TAU
				local p = f.mid + f.V(math.cos(a) * 0.4 * f.L, math.sin(a) * 0.3 * f.L, -0.3 * f.H + v * 0.9 * f.H)
				f.kit:spike(p, p + Z(1.2 * k), 0.3 * k * (1 - v), C.FIRE, 7, env(t, 0.2, 0.4, 0.8, 0.9) * (1 - v))
			end
			local u = seg(t, 0.5, 1.05)
			if u ~= nil then
				local start = f.V(0, 0, 0.5 * f.H)
				local finish = (f.T - f.mid) + f.V(0, 0.2 * f.L, 0.25 * f.H)
				local ctrl = (start + finish) / 2 + Z(0.8 * f.H)
				local w = ease(seg(t, 0.5, S.IMPACT) or 1)
				local p = bez(start, ctrl, finish, w)
				local fade = env(t, 0.5, 0.6, S.IMPACT, 1.05)
				f.kit:ghost("firebird", FIREBIRD, p, C.FIRE, 3, 0.45 * fade, 1.4)
				f.kit:light(f.mid + p, C.FIRE, 6 * fade)
				local pts = {}
				for i = 0, 7 do
					table.insert(pts, f.mid + bez(start, ctrl, finish, math.max(0, w - i * 0.05)))
				end
				f.kit:trail(pts, 1.5 * k, C.EMBER, 5, 0.5 * fade)
			end
			u = seg(t, S.IMPACT, 1.5)
			if u ~= nil then
				f.kit:orb(f.TC, (1 + 3 * ease(u)) * k, C.FIRE, 6, 0.7 * (1 - u), false)
				f.kit:ring(f.T + Z(0.1), (1 + 3.5 * u) * k, 0.3 * k, C.FIRE, 7, 1 - u)
				f.kit:burst(f.TC, u, 20, 4 * k, C.EMBER, 73, 0.15 * k, 0.8)
			end
			S.impact(f, C.FIRE, 3, 75, false)
		end,
	}
end
