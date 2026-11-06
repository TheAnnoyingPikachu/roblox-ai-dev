--!strict
-- LanternConfig holds every GDD C, F and H number (architecture lantern 3.1, 8): these pins fail
-- when a value drifts from the GDD tables or decision 0018 section 5.
local T = require("./framework")
local LanternConfig = require("../src/shared/LanternConfig")
local TrackRules = require("../src/shared/TrackRules")

local describe, it, expect = T.describe, T.it, T.expect

local function list(t: { any }): string
	local out = {}
	for _, x in t do
		table.insert(out, tostring(x))
	end
	return table.concat(out, " ")
end

local function sum(t: { number }): number
	local s = 0
	for _, x in t do
		s += x
	end
	return s
end

describe("LanternConfig numbers (GDD C, F, H)", function()
	it("pins the train and run values of C1 and C5", function()
		local C = LanternConfig
		expect(list(C.SPEED)).toBe("20 23 26")
		expect(`{C.ACCEL} {C.COAST} {C.COAL_PER_STUD * 60} {list(C.BUNKER)} {C.COAL_LOW}`).toBe("4 2 1 80 100 120 15")
		local s = C.STOKE
		expect(`{s.mult} {s.seconds} {s.coal} {s.cooldown}`).toBe("1.25 6 2 6")
		local l = C.LANTERN
		expect(
			`{l.max} {l.store} {l.autoBelow} {l.autoPour} {l.autoEvery} {l.mend} {l.mendMax} {l.mendCooldown} {l.depot}`
		).toBe("100 6 25 8 3 12 88 3 40")
		expect(`{C.HUB.grace} {C.HUB.firstSit} {C.DEPOT.max} {C.DEPOT.minStay} {C.DEPOT.grace} {C.END_CARD}`).toBe(
			"3 20 90 10 3 12"
		)
	end)

	it("pins the stop, fog and carrying values of C2 and C3", function()
		local s = LanternConfig.STOP
		expect(`{s.calm} {s.depth} {s.width} {s.minStay} {s.grace} {s.limbo} {s.fogV0} {s.fogAcc} {s.fogMax}`).toBe(
			"70 160 120 10 3 10 6 1 16"
		)
		local m = LanternConfig.MOVE
		expect(`{m.walk} {m.small} {m.big} {m.critterSolo} {m.critterDuo}`).toBe("16 15 13 9 13")
		local C = LanternConfig
		expect(`{C.REACH} {C.HELP_BREAK} {C.LOAD_BOX} {C.NEAR}`).toBe("8 14 6 70")
		local i = C.ITEMS
		expect(`{i.coal.coal} {i.parts.parts} {i.oil.oil} {i.supply.parts} {i.supply.tickets} {i.coal.tickets}`).toBe(
			"5 3 1 10 8 1"
		)
		expect(`{i.coal.big} {i.parts.big} {i.oil.big} {i.supply.big} {i.critter.big}`).toBe(
			"false false false true true"
		)
		local t = C.CRITTER_TICKETS
		expect(`{t.common} {t.uncommon} {t.rare} {t.epic} {t.legendary}`).toBe("10 15 25 50 100")
		expect(list(C.BIG_DEPTHS)).toBe("22 40 58 78 96 114 132 150")
	end)

	it("pins the night values of C4", function()
		local w = LanternConfig.WAVES
		expect(`{w.first} {w.gap} {list(w.perTurret)} {w.lake} {w.spawnMin} {w.spawnMax} {w.heightMin} {w.heightMax}`).toBe(
			"8 25 4 6 8 1 60 75 4 20"
		)
		expect(`{w.spread} {w.speed} {w.wobble} {w.reach}`).toBe("3 8 2 3")
		expect(list(LanternConfig.DIM)).toBe("6 4.5 3.5 3")
		local b = LanternConfig.BEAM
		expect(`{b.halfAngle} {list(b.range)} {list(b.puff)} {b.pitchMin} {b.pitchMax} {b.stale}`).toBe(
			"7 80 90 100 0.6 0.45 0.35 -15 75 0.5"
		)
		local l = LanternConfig.LAMPEATER
		expect(`{l.at} {l.warn} {l.radius} {l.height} {l.every} {l.dive} {l.shoo} {l.dim} {l.needBase} {l.needPer}`).toBe(
			"50 3 45 25 8 3 0.8 10 15 8"
		)
		-- C4's parenthetical "12 / (min(n, 4) + 1)" gives 6 / 4 / 3 / 2.5; the C4 and C6 tables,
		-- decision 0018 and the pacing script all use 6 / 4.5 / 3.5 / 3, pinned above.
	end)

	it("pins the Depot and reward values of F, H3 and 0018 section 5", function()
		local u = LanternConfig.UPGRADES
		expect(`{u[1].id} {list(u[1].costs)} {u[2].id} {list(u[2].costs)} {u[3].id} {list(u[3].costs)}`).toBe(
			"boiler 30 60 bunker 25 50 lamps 30 60"
		)
		local C = LanternConfig
		expect(`{C.COAL_BUY.coal} {C.COAL_BUY.parts} {C.OIL_BUY.cans} {C.OIL_BUY.parts}`).toBe("30 12 2 10")
		expect(`{C.TICKETS.depot} {C.TICKETS.dawn} {C.TICKETS.fed} {C.TICKETS.coop}`).toBe("30 150 50 0.1")
		local x = C.XP
		expect(`{x.small} {x.big} {x.rescue} {x.new} {x.puff} {x.stoke} {x.mend} {x.stop} {x.depot} {x.dawn}`).toBe(
			"2 5 20 50 2 1 3 5 40 150"
		)
		expect(`{C.CREW.max} {C.CREW.active} {C.CREW.activeMove} {C.WEEKLY_SALT}`).toBe("6 180 10 6006")
	end)

	it("sums every odds row to 10,000 in RARITIES order", function()
		expect(list(LanternConfig.RARITIES)).toBe("common uncommon rare epic legendary")
		local O = LanternConfig.ODDS
		expect(list(O.near)).toBe("7000 2500 500 0 0")
		expect(list(O.far.forest)).toBe("4600 3400 1500 500 0")
		expect(list(O.far.lake)).toBe("4000 3400 1800 800 0")
		expect(list(O.farLeg3.forest)).toBe("4300 3400 1500 500 300")
		expect(list(O.farLeg3.lake)).toBe("3700 3400 1800 800 300")
		for _, row in { O.near, O.far.forest, O.far.lake, O.farLeg3.forest, O.farLeg3.lake } do
			expect(sum(row)).toBe(10000)
		end
	end)
end)

describe("LanternConfig critters, tiles and cars", function()
	it("lists the 13 critters of H4 in order with their rarities, lines and existing tiles", function()
		local ids, rarities = {}, {}
		for _, c in LanternConfig.CRITTERS do
			table.insert(ids, c.id)
			table.insert(rarities, c.rarity)
			for _, line in c.lines do
				expect(line == "forest" or line == "lake").toBe(true)
			end
			for _, tile in c.tiles do
				expect(LanternConfig.tile(tile) ~= nil).toBe(true)
			end
			expect(#c.name > 0 and #c.look > 0).toBe(true)
		end
		expect(list(ids)).toBe(
			"mossmouse puddlefrog wickmole burrbun lanternbeetle fogpup acornowlet teapotcat reedfox mistfawn bellturtle moonhare emberkit"
		)
		expect(list(rarities)).toBe(
			"common common common common uncommon uncommon uncommon rare rare epic epic legendary exclusive"
		)
		expect(list((LanternConfig.critter("mistfawn") :: any).lines)).toBe("forest")
		expect(list((LanternConfig.critter("bellturtle") :: any).lines)).toBe("lake")
		expect(#(LanternConfig.critter("emberkit") :: any).lines).toBe(0)
		expect((LanternConfig.critter("moonhare") :: any).leg3).toBe(true)
		expect(#(LanternConfig.critter("moonhare") :: any).tiles).toBe(8)
		expect(LanternConfig.critter("nope")).toBeNil()
	end)

	it("has the 8 tiles, six a line, each with 24 small and 8 big sites at the C3 depths", function()
		expect(#LanternConfig.TILES).toBe(8)
		expect(list(LanternConfig.LINE_TILES.forest)).toBe("village farm windmill orchard inn mill")
		expect(list(LanternConfig.LINE_TILES.lake)).toBe("village farm inn mill lighthouse boathouse")
		for _, tile in LanternConfig.TILES do
			expect(#tile.small).toBe(24)
			expect(#tile.big).toBe(8)
			expect(#tile.blocks >= 3 and #tile.blocks <= 5).toBe(true)
			for i, site in tile.big do
				expect(site.z).toBe(LanternConfig.BIG_DEPTHS[i])
			end
			for _, site in tile.small do
				expect(site.z >= 15 and site.z <= 150).toBe(true)
			end
			for _, line in tile.lines do
				expect(table.find(LanternConfig.LINE_TILES[line], tile.id) ~= nil).toBe(true)
			end
			expect(#tile.lines >= 1).toBe(true)
		end
		expect(LanternConfig.tile("nope")).toBeNil()
	end)

	it("keeps every site and block inside the 120 x 160 footprint and no site inside a block", function()
		for _, tile in LanternConfig.TILES do
			local sites = {}
			for _, s in tile.small do
				-- small items spread 1 stud either side of their site
				table.insert(sites, { x = s.x - 1, z = s.z })
				table.insert(sites, { x = s.x + 1, z = s.z })
			end
			for _, s in tile.big do
				table.insert(sites, { x = s.x, z = s.z })
			end
			for _, s in sites do
				expect(math.abs(s.x) <= 60 and s.z >= 0 and s.z <= 160).toBe(true)
				for _, b in tile.blocks do
					local inside = math.abs(s.x - b.at.x) < b.size.x / 2 + 1.5
						and math.abs(s.z - b.at.z) < b.size.z / 2 + 1.5
					expect(`{tile.id} {s.x},{s.z} {inside}`).toBe(`{tile.id} {s.x},{s.z} false`)
				end
			end
			for _, b in tile.blocks do
				expect(math.abs(b.at.x) + b.size.x / 2 <= 60).toBe(true)
				expect(b.at.z - b.size.z / 2 >= 0 and b.at.z + b.size.z / 2 <= 160).toBe(true)
				expect(b.size.y <= 48 and b.at.y == b.size.y / 2).toBe(true)
			end
		end
	end)

	it("builds the cars as 22 + 16 + 16 + 18 studs with 2-stud gaps, 78 in all, 12 seats and 4 turrets", function()
		local cars = LanternConfig.CARS
		local ids, kinds, seatIds = {}, {}, {}
		local turrets = 0
		for i, car in cars do
			table.insert(ids, `{car.id}:{car.length}@{car.offset}`)
			if i > 1 then
				expect(car.offset).toBe(cars[i - 1].offset + cars[i - 1].length + 2)
			end
			for _, s in car.seats do
				kinds[s.kind] = (kinds[s.kind] or 0) + 1
				expect(seatIds[s.id]).toBeNil()
				seatIds[s.id] = true
				expect(math.abs(s.at.z) <= car.length / 2).toBe(true)
			end
			turrets += #car.turrets
			expect(#car.lanterns >= 1).toBe(true)
		end
		expect(list(ids)).toBe("engine:22@0 cargo:16@24 lamp:16@42 passenger:18@60")
		local last = cars[#cars]
		expect(last.offset + last.length).toBe(78)
		expect(LanternConfig.TRAIN_LENGTH).toBe(78)
		expect(`{kinds.stoker} {kinds.turret} {kinds.mender} {kinds.passenger} {turrets}`).toBe("1 4 1 6 4")
		for kind, n in LanternConfig.SEAT_COUNTS do
			expect(kinds[kind]).toBe(n)
		end
	end)

	it("authors the four tracks with stops at 700, 1,400 and 2,100, nights from 2,100, finishes at 5,700", function()
		for id, closed in { forest = true, lake = true, forestDawn = false, lakeDawn = false } do
			local track = LanternConfig.TRACKS[id]
			expect(`{id} {track.closed} {list(track.stops)} {track.nightFrom} {track.finish}`).toBe(
				`{id} {closed} 700 1400 2100 2100 5700`
			)
			local first = track.points[1]
			expect(`{first.x} {first.y} {first.z}`).toBe("10 0 0") -- the hub point
		end
		expect(`{LanternConfig.OUTER.forest} {LanternConfig.OUTER.lake}`).toBe("-1 1")
	end)

	it("measures 5,700 +- 20 studs a track, radius >= 150 by day and >= 600 from nightFrom (TrackRules)", function()
		for _, id in { "forest", "lake", "forestDawn", "lakeDawn" } do
			local track = LanternConfig.TRACKS[id]
			local path = TrackRules.build(track.points, track.closed)
			local day = TrackRules.radius(path, 0, track.nightFrom)
			local night = TrackRules.radius(path, track.nightFrom, track.finish)
			expect(`{id} {math.abs(path.length - 5700) <= 20} {day >= 150} {night >= 600}`).toBe(`{id} true true true`)
			-- the whole 78-stud train stands on straight track at every stop (and at the Depot on a loop)
			local halts = table.clone(track.stops)
			if track.closed then
				table.insert(halts, track.finish)
			end
			for _, d in halts do
				expect(`{id} {d} {TrackRules.radius(path, d - LanternConfig.TRAIN_LENGTH, d)}`).toBe(`{id} {d} inf`)
			end
		end
	end)

	it(
		"runs the Dawn tracks along their loop to 5,300, then 100+ studs away from the hub; the Lake mirrors the Forest",
		function()
			for _, line in { "forest", "lake" } do
				local loop = TrackRules.build(LanternConfig.TRACKS[line].points, true)
				local dawn = TrackRules.build(LanternConfig.TRACKS[line .. "Dawn"].points, false)
				local worst = 0
				for d = 10, 5290, 20 do
					local a, b = TrackRules.at(loop, d), TrackRules.at(dawn, d)
					worst = math.max(worst, math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2))
				end
				expect(worst < 0.5).toBe(true)
				local hub, station = TrackRules.at(loop, 0), TrackRules.at(dawn, 5700)
				expect(math.sqrt((hub.x - station.x) ^ 2 + (hub.z - station.z) ^ 2) > 100).toBe(true)
			end
			local f, l = LanternConfig.TRACKS.forest.points, LanternConfig.TRACKS.lake.points
			expect(#f).toBe(#l)
			for i = 1, #f, 97 do
				expect(math.abs(f[i].x - 10 + l[i].x - 10) < 1e-9 and f[i].z == l[i].z).toBe(true)
			end
		end
	)
end)

describe("LanternConfig meta (H5 to H7)", function()
	it("has the 8 quests of H5 on stats the save counts", function()
		local stats = {
			rescues = true,
			loads = true,
			puffs = true,
			stokes = true,
			depots = true,
			dawns = true,
			rareRescues = true,
		}
		local rows = {}
		for _, q in LanternConfig.QUESTS do
			expect(stats[q.stat]).toBe(true)
			table.insert(rows, `{q.id}:{q.goal}:{q.reward}`)
		end
		expect(list(rows)).toBe(
			"rescue3:3:100 rescue10:10:200 load20:20:100 puff30:30:100 stoke15:15:100 depot2:2:150 dawn1:1:250 rare1:1:150"
		)
	end)

	it("has the 14 cosmetics of H6 with their unlocks, and every grant is granted somewhere", function()
		local rows, seen = {}, {}
		for _, c in LanternConfig.COSMETICS do
			expect(seen[c.id]).toBeNil()
			seen[c.id] = true
			table.insert(rows, `{c.slot}:{c.id}:{c.level or c.price or c.grant}`)
		end
		expect(list(rows)).toBe(
			"livery:classic:1 livery:ember:5 livery:fern:10 livery:brass:2500 livery:ivory:6000 livery:mossback:album "
				.. "livery:midnight:login lamp:warm:1 lamp:mint:3 lamp:rose:8 lamp:sky:1200 lamp:gold:4000 "
				.. "lamp:moonlit:album lamp:aurora:login"
		)
		expect(`{LanternConfig.SLOTS.livery} {LanternConfig.SLOTS.lamp}`).toBe("classic warm")
		local granted = {}
		for _, m in LanternConfig.MILESTONES do
			if m.cosmetic then
				granted[m.cosmetic] = "album"
			end
		end
		for _, track in LanternConfig.LOGIN do
			for _, s in track do
				if s.cosmetic then
					granted[s.cosmetic] = "login"
				end
			end
		end
		for _, c in LanternConfig.COSMETICS do
			expect(`{c.id} {c.grant}`).toBe(`{c.id} {granted[c.id]}`)
		end
		expect(LanternConfig.cosmetic("nope")).toBeNil()
	end)

	it(
		"has 7 login slots a track: a week of 550 Tickets and the livery, a month of 1,400, the Ember Kit and Aurora",
		function()
			local function totals(track: string): (string, number)
				local counts, tickets = {}, 0
				for _, s in LanternConfig.LOGIN[track] do
					table.insert(counts, s.count)
					tickets += s.tickets or 0
				end
				return list(counts), tickets
			end
			local wc, wt = totals("week")
			local mc, mt = totals("month")
			expect(`{wc} = {wt}`).toBe("1 2 3 4 5 6 7 = 550")
			expect(`{mc} = {mt}`).toBe("3 7 12 18 22 26 30 = 1400")
			local week5, month4, month7 =
				LanternConfig.LOGIN.week[5], LanternConfig.LOGIN.month[4], LanternConfig.LOGIN.month[7]
			expect(`{week5.cosmetic} {week5.owned}`).toBe("midnight 150")
			expect(`{month4.critter} {month4.owned}`).toBe("emberkit 250")
			expect(`{month7.cosmetic} {month7.tickets} {month7.owned}`).toBe("aurora 400 400")
		end
	)

	it("has the album milestones, roles and pings of H4, H7 and I2", function()
		local m = LanternConfig.MILESTONES
		expect(`{m[1].count}:{m[1].tickets} {m[2].count}:{m[2].cosmetic} {m[3].count}:{m[3].cosmetic}:{m[3].tickets}`).toBe(
			"4:200 8:mossback 12:moonlit:1000"
		)
		local roles = {}
		for _, r in LanternConfig.ROLES do
			table.insert(roles, `{r.id}:{r.stat}:{list(r.tiers)}`)
		end
		expect(table.concat(roles, ", ")).toBe(
			"stoker:stokes:30 300 1500, lamplighter:puffs:100 1000 5000, scout:loads:50 500 2500, mender:mends:15 150 750"
		)
		local pings = {}
		for _, p in LanternConfig.PINGS do
			table.insert(pings, p.id)
		end
		expect(list(pings)).toBe("coal critter help back wisps thanks")
	end)
end)
