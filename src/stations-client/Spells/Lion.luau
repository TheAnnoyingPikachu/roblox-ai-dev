--!strict
-- The lions' spells (magic.py's lion and its variants). Drawn afresh each frame: see Spells.
return function(S: any)
	local C, Z, ease, seg, env = S.C, S.Z, S.ease, S.seg, S.env
	local TAU = S.TAU

	return {
		-- Golden Roar: glows gold as it draws in a breath, then roars a cone of golden light with rings of sound rolling
		-- down it
		lion = function(f)
			local k, t = f.k, f.t
			f.kit:aura(C.GOLD, 0.16 * env(t, 0.25, 0.75, 0.86, 1.0), 5)
			local mouth = f.A.nose
			local u = seg(t, 0.86, 1.3)
			if u ~= nil then
				local reach = ease(math.min(1, (t - 0.86) / (S.IMPACT - 0.86)))
				local fade = 1 - ease(math.max(0, (t - 1.05) / 0.25))
				local finish = mouth:Lerp(f.TC, reach)
				local d = f.TC - mouth
				d = if d.Magnitude > 1e-6 then d.Unit else f.fwd
				-- the cone of the roar, wide at the target
				f.kit:spike(finish + d * 0.1, mouth, 2.4 * k * reach, C.GOLD, 3, 0.3 * fade)
				for i = 0, 3 do
					local v = ((t - 0.86) * 3 + i / 4) % 1 * reach
					f.kit:ring(mouth:Lerp(f.TC, v), (0.3 + 2.2 * v) * k, 0.08 * k, C.GOLD, 7, 0.9 * fade, d)
				end
				f.kit:light(mouth, C.GOLD, 5 * fade)
			end
			S.impact(f, C.GOLD, 3.5, 27)
		end,

		-- Solar Flare: a sun with twelve rays rises behind its head, then fires a blazing beam that bursts into a star of
		-- light on the target
		creature_lion_sun_forge = function(f)
			local k, t = f.k, f.t
			local head = f.A.crown + f.V(0, 1.2, 1.4) * k
			local g = env(t, 0.2, 0.7, 0.95, 1.2)
			if g > 0 then -- a sun with twelve rays rises behind its head
				f.kit:orb(head, 1.3 * k * g, C.SUN, 8, g, nil, 6 * g)
				for i = 0, 11 do
					local a = t * 1.5 + i / 12 * TAU
					local d = f.V(0.0, math.cos(a), math.sin(a))
					f.kit:spike(
						head + d * 1.4 * k * g,
						head + d * (2.6 + 0.4 * (i % 2)) * k * g,
						0.22 * k,
						C.YELLOW,
						8,
						g
					)
				end
			end
			local u = seg(t, 0.86, 1.2)
			if u ~= nil then
				local reach = ease(math.min(1, (t - 0.86) / (S.IMPACT - 0.86)))
				local fade = 1 - ease(math.max(0, (t - 1.02) / 0.18))
				f.kit:beam(head, head:Lerp(f.TC, reach), 0.75 * k, C.SUN, 9, fade)
				f.kit:light(f.TC, C.SUN, 10 * fade)
			end
			u = seg(t, S.IMPACT, 1.4)
			if u ~= nil then -- a starburst of rays
				for i = 0, 11 do
					local a = i / 12 * TAU
					local d = f.V(math.cos(a), -0.2, math.sin(a)).Unit
					f.kit:spike(f.TC, f.TC + d * (1 + 5 * ease(u)) * k, 0.3 * k * (1 - u), C.YELLOW, 9, 1 - u)
				end
			end
			S.impact(f, C.SUN, 4, 77)
		end,

		-- Sun's Judgement (the Sahara Guardian): rears up as its halo blazes and sand whirls round it; a greater halo
		-- opens in the sky over the target, then it slams down and a pillar of sunlight falls through it, a crown of sun
		-- spikes bursting from the ground
		creature_lion_sahara_forge = function(f)
			local k, t = f.k, f.t
			-- the middle of the sun halo it wears: the crown anchor is the tip of one of its spikes (studs at its built
			-- 12.6 height)
			local halo = f.A.crown + f.V(-2.44, 1.22, -3.33) * (f.H / 12.6)
			local top = f.T + Z(11 * k)
			f.kit:aura(C.GOLD, 0.2 * env(t, 0.1, 0.6, 0.9, 1.1), 5)
			local g = env(t, 0.1, 0.5, 1.0, 1.3)
			if g > 0 then -- its halo blazes: a ring of light, sixteen turning rays, four gems circling
				f.kit:ring(halo, 1.3 * k * (1 + 0.25 * g), 0.1 * k, C.SUN, 9, g, f.V(0, 1, 0), nil, 24)
				for i = 0, 15 do
					local a = t * 2.5 + i / 16 * TAU
					local d = f.V(math.cos(a), 0.0, math.sin(a))
					f.kit:spike(
						halo + d * 1.4 * k,
						halo + d * (2.2 + 1.2 * (1 - i % 2)) * k * g,
						0.16 * k,
						C.YELLOW,
						9,
						g
					)
				end
				for i = 0, 3 do
					local a = -t * 4 + i / 4 * TAU
					local p = halo + f.V(math.cos(a), 0.0, math.sin(a)) * 2.0 * k
					f.kit:diamond(p, 0.22 * k, 0.5 * k, C.VIOLET, 7, g, t * 6)
				end
			end
			local w = env(t, 0.1, 0.4, 0.8, 0.95)
			if w > 0 then -- sand whirls up round it as it rears
				local feet = S.ground(f, halo + f.V(0, 2.5, 0) * k)
				f.kit:vortex(feet, 2.4 * k, 4.5 * k * w, C.SAND, t, 5, 1.5, 0.45 * w, nil, 0.2)
			end
			local s = env(t, 0.3, 0.75, 1.15, 1.4)
			if s > 0 then -- a second, greater halo opens in the sky over the target
				f.kit:ring(top, 3.2 * k * s, 0.14 * k, C.SUN, 9, s, nil, nil, 28)
				f.kit:ring(top, 2.4 * k * s, 0.06 * k, C.VIOLET, 7, s, nil, nil, 20)
				for i = 0, 11 do
					local a = -t * 2 + i / 12 * TAU
					local d = f.V(math.cos(a), math.sin(a), 0.0)
					f.kit:spike(top + d * 3.3 * k * s, top + d * (4.3 + 0.9 * (i % 2)) * k * s, 0.2 * k, C.YELLOW, 9, s)
				end
				for i = 0, 2 do -- rings drop down the column, closing on the target
					local v = ((t - 0.3) * 2.2 + i / 3) % 1
					f.kit:ring(
						top:Lerp(f.T, v),
						(3.0 - 1.6 * v) * k,
						0.05 * k,
						C.GOLD,
						6,
						0.7 * s * (1 - v),
						nil,
						nil,
						16
					)
				end
			end
			local u = seg(t, 0.86, 1.45)
			if u ~= nil then -- the judgement: a pillar of sunlight slams down, and its roar strikes with it
				local reach = ease(math.min(1, (t - 0.86) / (S.IMPACT - 0.86)))
				local fade = 1 - ease(math.max(0, (t - 1.15) / 0.3))
				f.kit:beam(top, top:Lerp(f.T, reach), 1.7 * k, C.SUN, 10, fade)
				f.kit:beam(top, top:Lerp(f.T, reach), 2.3 * k, C.VIOLET, 5, 0.35 * fade, false)
				f.kit:beam(f.A.nose, f.A.nose:Lerp(f.TC, reach), 0.35 * k, C.GOLD, 8, 0.8 * fade)
				f.kit:light(f.TC, C.SUN, 14 * fade)
			end
			u = seg(t, S.IMPACT, 1.55)
			if u ~= nil then
				local rise = ease(math.min(1, u * 4)) * (1 - ease(math.max(0, (u - 0.6) / 0.4)))
				for i = 0, 15 do -- a crown of sun spikes bursts out of the ground round the target
					local a = i / 16 * TAU
					local out = f.V(math.cos(a), math.sin(a), 0.0)
					local base = f.T + out * 2.4 * k
					local tip = base + (out * 0.45 + Z(1)).Unit * (3.2 + 2.0 * (1 - i % 2)) * k * rise
					f.kit:spike(base, tip, 0.42 * k, if i % 2 == 1 then C.GOLD else C.YELLOW, 8, rise)
				end
				for i = 0, 1 do -- two shock rings roll out, the second one violet
					local v = u - i * 0.16
					if v > 0 then
						local R = (1 + 7 * ease(math.min(1, v))) * k
						f.kit:shock(f.T + Z(0.08), R, 0.1 * k, if i == 1 then C.VIOLET else C.SUN, 1 - math.min(1, v))
					end
				end
				for i = 0, 7 do -- gems fly up and out
					local a = i / 8 * TAU + 0.4
					local p = f.TC
						+ f.V(math.cos(a), math.sin(a), 0.0) * 2.2 * k * (0.4 + ease(u))
						+ Z((5 * u - 4 * u * u) * k)
					f.kit:diamond(p, 0.3 * k, 0.7 * k, C.VIOLET, 7, 1 - u, u * 9)
				end
				if u < 0.5 then -- lightning down the pillar
					for i = 0, 3 do
						local a = i / 4 * TAU + 0.8
						local out = f.V(math.cos(a), math.sin(a), 0.0)
						f.kit:bolt(
							top + out * 2.0 * k,
							f.T + out * 3.0 * k,
							C.YELLOW,
							0.1 * k,
							0.14,
							nil,
							math.floor(t * 30) + i,
							nil,
							1 - u * 2
						)
					end
				end
			end
			S.impact(f, C.SUN, 5.5, 91)
		end,

		-- Shadow Claws: crouches low as a pool of shadow spreads from its paws under the target, then swipes and three
		-- giant claws rake up out of it
		creature_lion_shadow_forge = function(f)
			local k, t = f.k, f.t
			local paws = S.ground(f, (f.A.paw_l + f.A.paw_r) / 2)
			local spread = seg(t, 0.3, 0.86)
			local reach = if spread ~= nil then ease(spread) elseif t > 0.86 then 1.0 else 0
			local fade = 1 - ease(math.max(0, (t - 1.25) / 0.3))
			if reach > 0 and fade > 0 then -- a pool of shadow spreads to the target
				for s = 0, 5 do
					local p = paws:Lerp(f.T, reach * s / 5)
					f.kit:disc(p, (1.0 + 1.6 * s / 5) * k, C.DARK, 0, 0.85 * fade)
				end
				f.kit:ring(f.T + Z(0.05), 2.6 * k * reach, 0.08 * k, C.SHADOW, 7, fade)
			end
			local u = seg(t, 0.88, 1.5)
			if u ~= nil then -- three great claws rake up out of it
				local function taper(x: number): number
					return 1 - 0.9 * x
				end
				for i = 0, 2 do
					local x = (i - 1) * 1.0 * k
					local g = if u > i * 0.05 then ease(math.min(1, (u - i * 0.05) * 5)) else 0
					g *= 1 - ease(math.max(0, (u - 0.7) / 0.3))
					if g <= 0 then
						continue
					end
					local base = f.T + f.V(x, 2.2 * k, 0)
					local pts = {}
					for j = 0, 10 do
						local a = j / 10 * 1.4
						table.insert(pts, base + f.V(0, -(1 - math.cos(a)) * 3.6, math.sin(a) * 5.6) * k * g)
					end
					f.kit:tube(pts, 0.6 * k, C.DARK, 0.3, 1, nil, taper)
					f.kit:tube(pts, 0.68 * k, C.SHADOW, 5, 0.45, nil, taper)
				end
			end
			if 0.2 < t and t < 1.2 then
				f.kit:orb(f.A.tail, 0.4 * k, C.SHADOW, 8, 1, false, 2)
			end
			S.impact(f, C.SHADOW, 3.5, 79)
		end,
	}
end
