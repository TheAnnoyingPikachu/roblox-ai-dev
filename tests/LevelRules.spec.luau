--!strict
local T = require("./framework")
local BattleRules = require("../src/shared/BattleRules")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local LevelRules = require("../src/shared/LevelRules")
local WaveRuns = require("../src/shared/WaveRuns")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

local function teamTotal(team: { StationRules.Owned }): number
	local n = 0
	for _, a in team do
		for _, stat in StationConfig.STATS do
			n += StationRules.stat(a, stat)
		end
	end
	return n
end

local function kindOf(e: StationRules.Owned): string
	return (StationConfig.foe(e.s) :: StationConfig.Foe).kind
end

-- The highest level `team` clears in a row from level 1 (stops at `limit`).
local function reach(team: { StationRules.Owned }, limit: number): number
	for level = 1, limit do
		if not LevelRules.fight(team, level) then
			return level - 1
		end
	end
	return limit
end

describe("LevelRules.enemies", function()
	it("is the same team every time for the same level, of the crowd's size, real foes", function()
		local a, b = LevelRules.enemies(17), LevelRules.enemies(17)
		expect(#a).toBe(LevelRules.crowd(17).count)
		for k = 1, #a do
			expect(a[k].s).toBe(b[k].s)
			expect(a[k].stats.speed).toBe(b[k].stats.speed)
			expect(StationConfig.foe(a[k].s) ~= nil).toBeTruthy()
			expect(StationConfig.species(a[k].s)).toBeNil() -- a foe is never an animal
		end
	end)

	it(
		"opens with the wave-1 foes (knights and battle priests), adds a new foe every few waves, never before its first wave, and gets stronger to the last wave",
		function()
			for level = 1, 2 do
				for _, e in LevelRules.enemies(level) do
					expect((StationConfig.foe(e.s) :: StationConfig.Foe).from).toBe(1)
				end
			end
			local seen = {}
			for level = 1, 80 do
				for _, e in LevelRules.enemies(level) do
					local foe = StationConfig.foe(e.s) :: StationConfig.Foe
					seen[foe.id] = true
					if foe.kind ~= "dragon" then
						expect(foe.from ~= nil and level >= (foe.from :: number)).toBeTruthy()
					end
				end
			end
			for _, f in StationConfig.FOES do
				expect(seen[f.id]).toBe(true) -- every foe, the dragons too, turns up within 80 waves
			end
			expect(LevelRules.scale(2) > LevelRules.scale(1)).toBeTruthy()
			expect(teamTotal(LevelRules.enemies(200)) > teamTotal(LevelRules.enemies(100))).toBeTruthy()
			expect(LevelRules.enemies(LevelRules.LAST)[1].stats.health > StationConfig.STAT_MAX).toBeTruthy()
		end
	)

	it(
		"holds the Legion's speed after STEEP_FROM and steepens its health and strength to the last wave (decision 0107)",
		function()
			local from, last = LevelRules.STEEP_FROM, LevelRules.LAST
			expect(LevelRules.might(from)).toBe(1)
			expect(LevelRules.scale(last)).toBe(LevelRules.scale(from))
			-- every steep wave grows by more than the one before; at the last, health and strength together outgrow a boon
			local first, second = LevelRules.might(from + 1), LevelRules.might(from + 2) / LevelRules.might(from + 1)
			expect(first > 1).toBeTruthy()
			expect(second > first).toBeTruthy()
			expect((LevelRules.might(last) / LevelRules.might(last - 1)) ^ 2 > WaveRuns.CLAWS).toBeTruthy()
			local k = LevelRules.scale(from)
			for _, e in LevelRules.classic(last, true) do -- without its boss (decision 0127: a boss fights at BOSS_MULT)
				local foe = StationConfig.foe(e.s) :: StationConfig.Foe
				expect(e.stats.speed).toBe(math.floor(foe.stats.speed * k))
				expect(e.stats.health).toBe(math.floor(foe.stats.health * (k * LevelRules.might(last))))
			end
		end
	)

	it("adds the last wall only after END_FROM, END_GROWTH a wave on top (decision 0121)", function()
		local from, grow = LevelRules.END_FROM, LevelRules.END_GROWTH
		local saved = LevelRules.END_GROWTH
		LevelRules.END_GROWTH = 1
		local plain = { LevelRules.might(from), LevelRules.might(from + 10) }
		LevelRules.END_GROWTH = saved
		expect(LevelRules.might(from)).toBe(plain[1])
		expect(math.abs(LevelRules.might(from + 10) / plain[2] - grow ^ 10) < 1e-9).toBeTruthy()
		expect(from < LevelRules.LAST).toBeTruthy()
	end)

	it("ends every 10th wave with a dragon, a stronger one as the waves go on, and sends none otherwise", function()
		expect(LevelRules.boss(9)).toBeNil()
		for _, c in
			{
				{ 10, "dark_drake" },
				{ 20, "dark_drake" },
				{ 30, "shadow_dragon" },
				{ 50, "shadow_dragon" },
				{ 60, "ancient_alpha_dragon" },
				{ 70, "ancient_alpha_dragon" }, -- the rotation from ROTATE_FROM (decision 0127)
				{ 80, "siege_golem" },
				{ 120, "ogre_commander" },
				{ 150, "ancient_alpha_dragon" },
			}
		do
			expect((LevelRules.boss(c[1] :: number) :: StationConfig.Foe).id).toBe(c[2])
			local wave = LevelRules.enemies(c[1] :: number)
			expect(wave[#wave].s).toBe(c[2])
		end
		for level = 1, 120 do
			local wave = LevelRules.enemies(level)
			for i, e in wave do
				if kindOf(e) == "dragon" then
					expect(i).toBe(#wave)
					expect(level % LevelRules.BOSS_EVERY).toBe(0)
				end
			end
		end
	end)

	it("sends bigger crowds in rushes, minions first, as strong as the classic wave (decision 0101)", function()
		for _, level in { 1, 5, 12, 25, 45, 73 } do
			local row = LevelRules.crowd(level)
			local wave = LevelRules.enemies(level)
			expect(#wave).toBe(row.count)
			local minions, elites, lastRush = 0, 0, 1
			for _, e in wave do
				local foe = StationConfig.foe(e.s) :: StationConfig.Foe
				minions += if foe.minion then 1 else 0
				elites += if e.elite then 1 else 0
				expect((e.rush :: number) >= lastRush).toBeTruthy() -- rushes in order
				lastRush = e.rush :: number
			end
			expect(minions).toBe(row.minions)
			expect(elites).toBe(row.elites)
			expect(lastRush).toBe(row.rushes)
			local want = LevelRules.power(level) * (row.power or 1)
			local got = BattleRules.teamPower(wave, 2)
			expect(math.abs(got - want) <= want * LevelRules.MATCH).toBeTruthy()
		end
		expect(#LevelRules.classic(30)).toBe(LevelRules.TEAM_SIZE)
	end)

	it(
		"sends two and three players' teams a bigger, stronger crowd, but less than a wave each (decision 0108)",
		function()
			expect(LevelRules.PARTY_COUNT[1]).toBe(1)
			expect(LevelRules.PARTY_POWER[1]).toBe(1)
			for _, level in { 5, 25, 45, 73 } do
				local row = LevelRules.crowd(level)
				local solo = BattleRules.teamPower(LevelRules.enemies(level), 2)
				for players = 2, 3 do
					local wave = LevelRules.enemies(level, players)
					expect(#wave).toBe(math.floor(row.count * LevelRules.PARTY_COUNT[players] + 0.5))
					local got = BattleRules.teamPower(wave, 2)
					local want = LevelRules.power(level) * (row.power or 1) * LevelRules.PARTY_POWER[players]
					expect(math.abs(got - want) <= want * LevelRules.MATCH).toBeTruthy()
					expect(got > solo).toBeTruthy()
					expect(got < solo * players).toBeTruthy() -- easier fought together
				end
			end
			local dragons = 0
			for _, e in LevelRules.enemies(30, 3) do -- one boss, however many come
				dragons += if (StationConfig.foe(e.s) :: StationConfig.Foe).kind == "dragon" then 1 else 0
			end
			expect(dragons).toBe(1)
		end
	)

	it("fights a foe by its role and group, like an animal", function()
		local bulwark = StationConfig.foe("heavy_knight") :: StationConfig.Foe
		local f = BattleRules.fighter({ s = bulwark.id, stats = bulwark.stats }, 2, 1)
		expect(f.role).toBe("defense")
		expect(f.group).toBe("solitary")
		local squire = StationConfig.foe("shadow_knight") :: StationConfig.Foe
		local banner = StationConfig.foe("battle_priest") :: StationConfig.Foe
		local pair =
			BattleRules.lineup({ { s = squire.id, stats = squire.stats }, { s = banner.id, stats = banner.stats } }, 2)
		local alone = BattleRules.fighter({ s = squire.id, stats = squire.stats }, 2, 1)
		expect(pair[1].dmg > alone.dmg).toBeTruthy() -- two pack foes: the pack bonus
	end)
end)

describe("LevelRules.fight", function()
	it("lets three commons clear the first levels but walls them later", function()
		local starters = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		local r = reach(starters, 200)
		expect(r >= 3).toBeTruthy()
		expect(r < 60).toBeTruthy()
	end)

	it("makes training and variants push further", function()
		local starters = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		local trained = {}
		for _, a in starters do
			for _, st in StationConfig.STATIONS do
				a = StationRules.train(a, st.id, 1e12) -- every stat to level 70
			end
			table.insert(trained, a)
		end
		local variants =
			{ owned("lion", "sun_lion"), owned("rhino", "lava_rhino"), owned("flamingo", "phoenix_flamingo") }
		local base, better, best = reach(starters, 400), reach(trained, 400), reach(variants, 400)
		expect(better > base).toBeTruthy()
		expect(best > base).toBeTruthy()
		expect(better < 400 and best < 400).toBeTruthy()
	end)

	it("never sends a Titan as a level enemy, and a Titan carries a team further", function()
		for _, level in { 1, 20, 100 } do
			for _, e in LevelRules.enemies(level) do
				expect(StationRules.role(e) ~= "titan").toBeTruthy()
			end
		end
		local team = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		local without = reach(team, 400)
		table.insert(team, owned("elephant"))
		expect(reach(team, 400) > without).toBeTruthy()
	end)
end)

describe("LevelRules.reward", function()
	it("pays more for higher levels and a part for replays", function()
		expect(LevelRules.reward(1, 0)).toBe(LevelRules.REWARD_START)
		expect(LevelRules.reward(20, 19) > LevelRules.reward(10, 9)).toBeTruthy()
		expect(LevelRules.reward(5, 9)).toBe(math.floor(LevelRules.reward(5, 4) * LevelRules.REPLAY_PCT / 100))
	end)
end)

describe("LevelRules.xp and samples", function()
	it("pay XP for every clear, samples from wave 5 and double on boss waves, and a part for replays", function()
		expect(LevelRules.xp(1, 0)).toBe(LevelRules.XP_START + LevelRules.XP_PER_LEVEL)
		expect(LevelRules.xp(5, 9)).toBe(math.floor(LevelRules.xp(5, 4) * LevelRules.REPLAY_PCT / 100))
		expect(LevelRules.samples(4, 0)).toBe(0)
		expect(LevelRules.samples(5, 4)).toBe(1)
		expect(LevelRules.samples(10, 9)).toBe(4) -- a boss wave drops double
		expect(LevelRules.samples(10, 10)).toBe(1) -- a replay a quarter of that
		expect(LevelRules.samples(40, 39) > LevelRules.samples(20, 19)).toBeTruthy()
	end)
end)

describe("LevelRules.stage (decision 0106)", function()
	it("makes a foe of the line a boss at BOSS_MULT, marked as the boss (decision 0127)", function()
		local wave = LevelRules.enemies(80)
		local boss = wave[#wave]
		expect(boss.s).toBe("siege_golem")
		expect(boss.boss).toBe(true)
		for i = 1, #wave - 1 do
			expect(wave[i].boss).toBeNil()
			if wave[i].s == "siege_golem" and not wave[i].elite then -- the same foe in the line is a third as strong
				expect(boss.stats.health > 2 * wave[i].stats.health).toBeTruthy()
			end
		end
	end)

	it("groups the waves into stages of STAGE that each end on a boss wave", function()
		local first = LevelRules.stage(1)
		expect(first.n).toBe(1)
		expect(first.name).toBe("The Vanguard")
		expect(first.first).toBe(1)
		expect(first.last).toBe(10)
		expect(LevelRules.stage(10).n).toBe(1)
		expect(LevelRules.stage(11).name).toBe("The Charge")
		expect(LevelRules.stage(35).name).toBe("The Dark Host")
		expect(LevelRules.stage(45).name).toBe("The Black Banners")
		expect(LevelRules.stage(51).name).toBe("The Drake's Shadow")
		expect(LevelRules.stage(300).name).toBe("The Ancient")
		local seen = {}
		for n = 1, LevelRules.LAST // LevelRules.STAGE do -- every stage its own name (decision 0127)
			local name = LevelRules.STAGE_NAMES[n]
			expect(name ~= nil and seen[name] == nil).toBeTruthy()
			seen[name] = true
		end
		expect(LevelRules.stage(140).n).toBe(14)
		for level = 1, 100 do
			local s = LevelRules.stage(level)
			expect(level >= s.first and level <= s.last).toBeTruthy()
			expect(s.last % LevelRules.BOSS_EVERY).toBe(0)
		end
	end)
end)
