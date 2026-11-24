--!strict
-- The elephants' spells (magic.py's elephant and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env = S.C, S.Z, S.ease, S.seg, S.env
	local TAU = S.TAU

	return {
		-- Titan Orb: rears with its trunk high, gathering a huge violet orb at its tip, then throws it with its trunk
		elephant = function(f)
			local k, t = f.k, f.t
			local tip = f.A.trunk
			local grow = seg(t, 0.25, 0.8)
			if grow ~= nil then
				local R = 1.5 * k * ease(grow)
				f.kit:orb(tip + Z(R * 0.6), R, C.VIOLET, 7, 1, nil, 5)
				for i = 0, 9 do -- sparks drawn in
					local a = i / 10 * TAU + t * 4
					local v = (t * 2.5 + i / 10) % 1
					f.kit:spark(
						tip + Z(R * 0.6) + f.V(math.cos(a), math.sin(a) * 0.5, math.sin(a)) * (1 - v) * 4 * k,
						0.14 * k,
						C.GOLD,
						8,
						v
					)
				end
			end
			S.flight(f, tip + Z(1.5 * k * 0.6), f.TC, 0.8, S.IMPACT, 2 * k, function(p: Vector3)
				f.kit:orb(p, 1.5 * k, C.VIOLET, 8, 1, nil, 5)
			end, { C.VIOLET, 1.4 * k })
			S.impact(f, C.VIOLET, 5, 37)
			local u = seg(t, S.IMPACT, S.IMPACT + 0.5)
			if u ~= nil then
				f.kit:orb(f.TC, (1.5 + 3.5 * ease(u)) * k, C.GOLD, 4, 0.5 * (1 - u), false)
			end
		end,

		-- Frozen Tomb: trumpets a swirl of frost, slams down and sends a line of ice spikes racing to the target,
		-- freezing it in a block of ice that shatters
		creature_elephant_frost_forge = function(f)
			local k, t = f.k, f.t
			local tip = f.A.trunk
			local breath = env(t, 0.3, 0.45, 0.72, 0.82)
			if breath > 0 then -- frost swirling off its raised trunk
				f.kit:vortex(tip, 0.8 * k, 3 * k, C.FROST, t, 3, 3, 0.5 * breath, nil, 0.1)
			end
			local base = S.ground(f, f.A.chest)
			for i = 0, 6 do -- a line of ice spikes racing to the target
				local t0 = 0.82 + (S.IMPACT - 0.82) * i / 6
				local u = seg(t, t0, t0 + 0.65)
				if u == nil then
					continue
				end
				local p = base:Lerp(f.T, (i + 0.5) / 7.5) + f.V(if i % 2 ~= 0 then 0.8 else -0.8, 0, 0) * k
				local h = (1.6 + 0.3 * i) * k * ease(math.min(1, u * 5)) * (1 - ease(math.max(0, (u - 0.6) / 0.4)))
				f.kit:spike(p, p + Z(h) + f.V(0, -0.4, 0) * k, 0.55 * k, C.FROST, 4, 0.85)
			end
			local u = seg(t, S.IMPACT, 1.55)
			if u ~= nil then -- the target frozen in a block of ice, which shatters
				if u < 0.55 then
					local g = ease(math.min(1, u * 5))
					f.kit:box(f.T + Z(2.6 * k), { 3.0 * k * g, 3.0 * k * g, 5.6 * k * g }, C.FROST, 1.5, 0.45)
				else
					local s = (u - 0.55) / 0.45
					for i = 0, 9 do
						local a = i / 10 * TAU
						local q = f.T
							+ f.V(math.cos(a), math.sin(a), 0) * (1.2 + 3 * s) * k
							+ Z((1 + (i % 3) * 1.6) * k + 2 * k * s - 3 * k * s * s)
						f.kit:diamond(q, 0.35 * k, 0.9 * k, C.FROST, 3, 1 - s, t * 8 + i)
					end
				end
			end
			S.impact(f, C.FROST, 4, 87)
		end,

		-- War Axe (SHANNON's, 2026-11-22, its effects toned down a little): the axe in its trunk grows into a huge axe
		-- of iron and fire, which it swings up over its head and brings down through the target, splitting the ground
		creature_elephant_war_forge = function(f)
			local k, t = f.k, f.t
			local IRON, HAFT = Color3.new(0.1, 0.08, 0.08), Color3.new(0.28, 0.15, 0.07)
			local pivot = f.A.trunk -- its trunk's grip
			local g = ease(math.clamp((t - 0.42) / 0.48, 0, 1)) -- how far it has grown: most of it in the swing
			local sc = 0.3 + 0.7 * g
			local bd = 3.4 * k -- how far the blade's edge stands off the haft, full grown
			local v = f.TC - pivot
			local full = math.sqrt(math.max(v.Magnitude ^ 2 - bd ^ 2, 1))
			local reach = k + (full - k) * g
			-- the angle (0 = straight up, + forward) at which the edge meets the target
			local hit = math.atan2(v:Dot(f.fwd), v.Y) - math.atan2(bd, full)
			local back = -1.25 -- raised behind its head, over its back
			local function d(a: number): Vector3 -- along the haft
				return f.V(0, -math.sin(a), math.cos(a))
			end
			local function s(a: number): Vector3 -- the way the edge faces (the swing)
				return f.V(0, -math.cos(a), -math.sin(a))
			end
			local form = env(t, 0.25, 0.4, 2, 3)
			local swing = seg(t, 0.76, S.IMPACT)
			local gone = seg(t, 1.12, 1.45)
			local a
			if t < 0.76 then
				a = 0.35 + (back - 0.35) * ease(math.clamp((t - 0.3) / 0.45, 0, 1)) -- drawn back over its head
			elseif swing ~= nil then
				a = back + (hit - back) * swing ^ 2.2 -- faster and faster
			else
				a = hit + 0.05 * ease(math.min(1, (t - S.IMPACT) / 0.1)) -- bites in a little further
			end
			local alpha = if t < 1.12 then form elseif gone ~= nil then 1 - gone else 0

			local rune = env(t, 0.2, 0.45, 0.8, 0.95) -- the war rune flares over its back
			local top = f.A.back + Z(1.5 * k)
			if rune > 0 then
				f.kit:circle(top, 2.6 * k * rune, C.EMBER, t * 3, 5, 0.7 * rune, 6)
				f.kit:light(top, C.EMBER, 3 * rune)
			end
			if t > 0.25 and t < 0.76 then -- embers stream from the rune into the axe as it grows
				for i = 0, 7 do
					local u = (t * 2.2 + i / 8) % 1
					local q = pivot + d(a) * reach * ((i % 6) / 6)
					f.kit:spark(top:Lerp(q, ease(u)), 0.12 * k, C.FIRE, 6, 0.7 * (1 - u) * form)
				end
			end

			if alpha > 0.01 then
				local hd = pivot + d(a) * reach -- the axe's head
				f.kit:tube({ pivot - d(a) * k * sc, hd + d(a) * k * sc }, 0.26 * k * sc, HAFT, 0, alpha) -- the haft
				for j = 0, 3 do -- iron bands with glowing runes
					local at = pivot + d(a) * (reach * (0.15 + 0.22 * j))
					f.kit:ring(at, 0.32 * k * sc, 0.09 * k * sc, C.EMBER, 4, alpha, d(a), nil, 10)
				end
				f.kit:spike(hd + d(a) * 0.8 * k * sc, hd + d(a) * 2.2 * k * sc, 0.4 * k * sc, IRON, 0, alpha) -- top
				f.kit:spike(hd - s(a) * 0.3 * k * sc, hd - s(a) * 1.8 * k * sc, 0.45 * k * sc, IRON, 0, alpha) -- back
				-- the blade: a great half moon off the haft, iron with a molten edge
				local re, span = 3.0 * k * sc, 0.95
				local c = hd + s(a) * (bd * sc - re)
				local edge = {}
				for i = 0, 14 do
					local x = -span + 2 * span * i / 14
					table.insert(edge, c + (s(a) * math.cos(x) + d(a) * math.sin(x)) * re)
				end
				local rim = { hd - d(a) * 0.8 * k * sc }
				for _, p in edge do
					table.insert(rim, p)
				end
				table.insert(rim, hd + d(a) * 0.8 * k * sc)
				local hub = hd + s(a) * 0.3 * k * sc
				for i = 1, #rim - 1 do
					f.kit:triangle(hub, rim[i], rim[i + 1], IRON, 0, alpha, 0.24 * k)
				end
				local hot = if swing ~= nil or t >= S.IMPACT then 1 else 0.6
				f.kit:tube(edge, 0.18 * k * sc, C.FIRE, 6 * hot, alpha, false, function(x: number)
					return 0.5 + 0.5 * math.sin(math.pi * x)
				end)
				local mark = hd + s(a) * 1.1 * k * sc -- a rune ring on the blade
				f.kit:ring(mark, 0.7 * k * sc, 0.08 * k * sc, C.EMBER, 4, 0.6 * alpha, f.V(1, 0, 0))
				if swing ~= nil then -- a sheet of fire behind the edge as it sweeps
					for _, sheet in { { 1.1, C.EMBER, 4, 0.3 }, { 0.45, C.YELLOW, 6, 0.35 } } do
						local pts = {}
						for i = 0, 9 do
							local ai = back + (hit - back) * math.max(0, swing - i * 0.07) ^ 2.2
							table.insert(pts, pivot + d(ai) * reach + s(ai) * bd)
						end
						f.kit:trail(pts, sheet[1] * k, sheet[2], sheet[3], sheet[4])
					end
				end
			end

			local u = seg(t, S.IMPACT, 1.55)
			if u ~= nil then -- the ground splits along the cut
				local split = ease(math.min(1, u * 4)) * (1 - ease(math.max(0, (u - 0.55) / 0.45)))
				local along = f.fwd * 3.5 * k * split
				f.kit:tube({ f.T - along + Z(0.05), f.T + along + Z(0.05) }, 0.25 * k, C.LAVA, 6, 0.8 * split)
				for i = 0, 5 do
					local side = if i % 2 ~= 0 then 1 else -1
					local q = f.T + f.fwd * (i - 2.5) * 1.3 * k * split + f.V(0.7 * side * k, 0, 0)
					f.kit:spike(q, q + Z(1.4 * k * split) + f.V(0.5 * side * k, 0, 0), 0.5 * k, C.ROCK, 0, 1)
				end
				f.kit:burst(f.TC, u, 14, 4 * k, C.EMBER, 93, 0.15 * k, 0.9)
			end
			if gone ~= nil then -- the axe bursts into embers
				f.kit:burst(pivot + d(a) * reach + s(a) * 1.2 * k, gone, 10, 3 * k, C.FIRE, 95, 0.13 * k, 1.2)
			end
			S.impact(f, C.FIRE, 4, 97)
		end,

		-- Dawnbreaker (the Sahara Mammoth): a sun wheel blazes over its back as a sun sigil turns under the target; it
		-- stamps, a line of sun spikes races along the ground, and two colossal tusks of light erupt either side of the
		-- target and cross over it
		creature_elephant_sahara_forge = function(f)
			local k, t = f.k, f.t
			local feet = S.ground(f, (f.A.paw_l + f.A.paw_r) / 2)
			local back = f.A.back -- the tip of the sun spike on its back
			f.kit:aura(C.GOLD, 0.2 * env(t, 0.1, 0.6, 0.9, 1.1), 5)
			local g = env(t, 0.1, 0.5, 0.95, 1.25)
			if g > 0 then -- a sun wheel blazes over its back and its tusks glow
				f.kit:ring(back, 1.5 * k * g, 0.1 * k, C.SUN, 9, g, f.V(0, 1, 0), nil, 24)
				for i = 0, 11 do
					local a = t * 2 + i / 12 * TAU
					local d = f.V(math.cos(a), 0.0, math.sin(a))
					local tip = back + d * (2.6 + 0.8 * (i % 2)) * k * g
					f.kit:spike(back + d * 1.6 * k * g, tip, 0.16 * k, C.YELLOW, 9, g)
				end
				f.kit:orb(f.A.nose, 0.45 * k * g, C.SUN, 8, g)
			end
			local s = env(t, 0.25, 0.7, 1.2, 1.5)
			if s > 0 then -- a sun sigil turns on the ground under the target, gems circling over it
				f.kit:circle(f.T, 3.4 * k * s, C.GOLD, t * 1.5, 6, 0.9 * s, 12)
				for i = 0, 3 do
					local a = t * 3 + i / 4 * TAU
					local p = f.TC + f.V(math.cos(a), math.sin(a), 0.0) * 2.6 * k + Z(1.5 * k)
					f.kit:diamond(p, 0.25 * k, 0.6 * k, C.VIOLET, 7, s, t * 6)
				end
			end
			local u = seg(t, 0.84, 1.3)
			if u ~= nil then -- it stamps: a shock rolls out from its feet and a line of sun spikes races to the target
				local run = ease(math.min(1, (t - 0.84) / (S.IMPACT - 0.84)))
				local sink = 1 - ease(math.max(0, (t - 1.05) / 0.25))
				local wide = (1 + 4 * ease(math.min(1, u * 2))) * k
				f.kit:shock(feet + Z(0.08), wide, 0.1 * k, C.SUN, 1 - math.min(1, u * 2))
				for i = 0, 8 do
					local v = (i + 1) / 10
					if v <= run and sink > 0 then
						local side = f.V(if i % 2 == 1 then 0.5 else -0.5, 0.0, 0.0) * k
						local p = feet:Lerp(f.T, v) + side
						local tip = p + side * 0.6 + Z((1.2 + 1.8 * v) * k * sink)
						f.kit:spike(p, tip, 0.35 * k, if i % 2 == 1 then C.GOLD else C.YELLOW, 8, sink)
					end
				end
			end
			u = seg(t, S.IMPACT, 1.55)
			if u ~= nil then
				local rise = ease(math.min(1, u * 3.5)) * (1 - ease(math.max(0, (u - 0.65) / 0.35)))
				if rise > 0 then -- two colossal tusks of light erupt either side of the target and cross over it
					local function taper(x: number): number
						return 1 - 0.92 * x
					end
					for _, sgn in { -1, 1 } do
						local pts = {}
						for j = 0, 10 do
							local a = j / 10 * 1.4
							local at = f.V(sgn * (3.2 - 4.2 * (1 - math.cos(a))), 0.0, 7.5 * math.sin(a))
							table.insert(pts, f.T + at * k * rise)
						end
						f.kit:tube(pts, 0.75 * k, C.SUN, 6, rise, nil, taper)
						f.kit:tube(pts, 0.85 * k, C.GOLD, 3, 0.35 * rise, nil, taper)
					end
					f.kit:light(f.TC, C.SUN, 14 * rise)
				end
				for i = 0, 11 do -- a starburst of rays
					local a = i / 12 * TAU
					local d = f.V(math.cos(a), math.sin(a), 0.35).Unit
					f.kit:spike(f.TC, f.TC + d * (1 + 6 * ease(u)) * k, 0.3 * k * (1 - u), C.YELLOW, 9, 1 - u)
				end
				f.kit:shock(f.T + Z(0.08), (1 + 8 * ease(u)) * k, 0.1 * k, C.VIOLET, 1 - u)
				for i = 0, 7 do -- gems fly up and out
					local a = i / 8 * TAU + 0.4
					local p = f.TC
						+ f.V(math.cos(a), math.sin(a), 0.0) * 2.2 * k * (0.4 + ease(u))
						+ Z((5 * u - 4 * u * u) * k)
					f.kit:diamond(p, 0.3 * k, 0.7 * k, C.VIOLET, 7, 1 - u, u * 9)
				end
			end
			S.impact(f, C.SUN, 6, 93)
		end,

		-- Tusk heave (the Sahara Mammoth's regular attack; the hit at 0.44 s): its tusks glow as it drives in, the ground
		-- breaks into stone spikes under the target and a crescent of sunlight follows the tusks up
		["creature_elephant_sahara_forge@attack"] = function(f)
			local k, t = f.k, f.t
			local g = env(t, 0.15, 0.3, 0.5, 0.65)
			if g > 0 then
				f.kit:orb(f.A.nose, 0.4 * k * g, C.SUN, 8, g)
			end
			local u = seg(t, 0.38, 0.85)
			if u ~= nil then
				local rise = ease(math.min(1, u * 4)) * (1 - ease(math.max(0, (u - 0.55) / 0.45)))
				for i = -2, 2 do
					local p = f.T + f.V(0.9 * i, 0.0, 0.0) * k
					local tip = p + Z((1.4 + 0.8 * (2 - math.abs(i))) * k * rise)
					f.kit:spike(p, tip, 0.4 * k, if i % 2 == 0 then C.GOLD else C.SAND, 3, rise)
				end
				local at = f.TC + Z((-1 + 3 * ease(u)) * k)
				f.kit:crescent(at, 2.6 * k, 0.5 * k, C.SUN, f.V(1, 0, 0), f.V(0, -0.5, 1), 8, 1 - u)
				f.kit:shock(f.T + Z(0.08), (0.5 + 4 * ease(u)) * k, 0.08 * k, C.VIOLET, 1 - u)
				f.kit:burst(f.TC, u, 10, 3 * k, C.SAND, 37, 0.12 * k)
			end
		end,
	}
end
