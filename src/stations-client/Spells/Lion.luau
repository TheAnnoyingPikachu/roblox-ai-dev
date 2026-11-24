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
