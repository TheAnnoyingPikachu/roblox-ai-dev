--!strict
local T = require("./framework")
local StationConfig = require("../src/shared/StationConfig")
local StationRules = require("../src/shared/StationRules")
local BattleRules = require("../src/shared/BattleRules")

local describe, it, expect = T.describe, T.it, T.expect

local function owned(id: string, variant: string?): StationRules.Owned
	return { s = id, v = variant, stats = StationRules.versionStats(id, variant) :: StationConfig.Stats }
end

-- A made-up animal of species `id` with the given numbers (40 where not given).
local function custom(id: string, over: { [string]: number }?): StationRules.Owned
	local st = { speed = 40, strength = 40, stamina = 40, mana = 40, health = 40, defence = 40 } :: any
	for k, x in over or {} do
		st[k] = x
	end
	return { s = id, stats = st :: StationConfig.Stats }
end

local function three(id: string): { StationRules.Owned }
	return { owned(id), owned(id), owned(id) }
end

describe("BattleRules.fighter", function()
	it("takes the role and group from the species", function()
		expect(BattleRules.fighter(owned("lion"), 1, 1).role).toBe("attack")
		expect(BattleRules.fighter(owned("rhino"), 1, 1).role).toBe("defense")
		expect(BattleRules.fighter(owned("meerkat"), 1, 1).role).toBe("utility")
		expect(BattleRules.fighter(owned("elephant"), 1, 4).role).toBe("titan")
		expect(BattleRules.fighter(owned("lion"), 1, 1).group).toBe("pack")
		expect(BattleRules.fighter(owned("rhino"), 1, 1).group).toBe("solitary")
	end)

	it("gives each stat exactly one job", function()
		-- Speed: attack speed. Stamina: the rest between attacks. Strength: damage. Mana: energy
		-- per attack. Health: HP. Defence: damage reduction.
		local JOB =
			{ speed = "swing", stamina = "rest", strength = "dmg", mana = "gain", health = "maxHp", defence = "def" }
		local BETTER = { swing = -1, rest = -1, dmg = 1, gain = 1, maxHp = 1, def = 1 }
		local base = custom("lion")
		local before = BattleRules.fighter(base, 1, 1) :: any
		for _, st in StationConfig.STATIONS do
			local after = BattleRules.fighter(StationRules.train(base, st.id, 1e12), 1, 1) :: any
			for field, direction in BETTER do
				if field == JOB[st.stat] then
					expect((after[field] - before[field]) * direction > 0).toBeTruthy()
				else
					expect(after[field]).toBe(before[field])
				end
			end
		end
	end)

	it(
		"halves the swing at 100 Speed and the rest at 100 Stamina, and lands the first attack after one swing",
		function()
			local slow = BattleRules.fighter(custom("lion", { speed = 0, stamina = 0 }), 1, 1)
			expect(slow.swing).toBe(BattleRules.SWING)
			expect(slow.rest).toBe(BattleRules.REST)
			expect(slow.next).toBe(slow.swing)
			local quick = BattleRules.fighter(custom("lion", { speed = 100, stamina = 100 }), 1, 1)
			expect(quick.swing).toBe(BattleRules.SWING / 2)
			expect(quick.rest).toBe(BattleRules.REST / 2)
		end
	)

	it("takes HP from Health and damage from Strength, with Attack hitting harder", function()
		local a = BattleRules.fighter(custom("lion"), 1, 1)
		expect(a.maxHp).toBe(BattleRules.HP_BASE + 40 * BattleRules.HP_PER_HEALTH)
		local u = BattleRules.fighter(custom("meerkat"), 1, 1)
		expect(u.dmg).toBe(BattleRules.DMG_BASE + 40 * BattleRules.DMG_PER_STRENGTH)
		expect(a.dmg).toBe(math.floor(u.dmg * BattleRules.ATTACK_BONUS))
		expect(a.maxHp).toBe(u.maxHp)
	end)
end)

describe("BattleRules stats in a wave fight", function()
	-- one attacker against a punch bag that barely fights back: how long it takes to finish it
	local function bag(over: { [string]: number }?): StationRules.Owned
		local st = { speed = 0, strength = 0, stamina = 0, mana = 0, health = 600, defence = 0 }
		for k, x in over or {} do
			st[k] = x
		end
		return custom("lion", st)
	end
	local function hitter(over: { [string]: number }?): StationRules.Owned
		local st = { mana = 0, health = 4000, defence = 0 }
		for k, x in over or {} do
			st[k] = x
		end
		return custom("lion", st)
	end
	local function seconds(h: StationRules.Owned, b: StationRules.Owned): number
		local won, _, took = BattleRules.battle({ h }, { b })
		expect(won).toBe(true)
		return took
	end

	it("ends sooner with more Strength, more Speed, more Stamina or more Mana", function()
		local plain = seconds(hitter(), bag())
		expect(seconds(hitter({ strength = 80 }), bag()) < plain).toBeTruthy()
		expect(seconds(hitter({ speed = 100 }), bag()) < plain).toBeTruthy()
		expect(seconds(hitter({ stamina = 100 }), bag()) < plain).toBeTruthy()
		local some, lots = seconds(hitter({ mana = 40 }), bag()), seconds(hitter({ mana = 90 }), bag())
		expect(some < plain).toBeTruthy()
		expect(lots < some).toBeTruthy()
	end)

	it("lasts longer against more Health or more Defence: 100 Defence about doubles it", function()
		local plain = seconds(hitter(), bag())
		expect(seconds(hitter(), bag({ health = 1200 })) > plain).toBeTruthy()
		local some, lots = seconds(hitter(), bag({ defence = 50 })), seconds(hitter(), bag({ defence = 100 }))
		expect(some > plain).toBeTruthy()
		expect(lots > some).toBeTruthy()
		expect(lots >= plain * 1.8 and lots <= plain * 2.2).toBeTruthy()
	end)

	it("lets the faster of two otherwise equal animals win, from either side", function()
		local fast, slow = custom("lion", { speed = 60 }), custom("lion")
		expect((BattleRules.battle({ fast }, { slow }))).toBe(true)
		expect((BattleRules.battle({ slow }, { fast }))).toBe(false)
	end)
end)

describe("BattleRules.lineup groups", function()
	it("gives a pack animal 10% damage and HP for each other pack animal on the team", function()
		expect(StationConfig.PACK_PCT).toBe(10)
		expect(StationConfig.SOLITARY_PCT).toBe(25)
		local raw = BattleRules.fighter(owned("lion"), 1, 1)
		local alone = BattleRules.lineup({ owned("lion") }, 1)[1]
		expect(alone.dmg).toBe(raw.dmg)
		expect(alone.maxHp).toBe(raw.maxHp)
		local pair = BattleRules.lineup({ owned("lion"), owned("jackal") }, 1)[1]
		expect(pair.dmg).toBe(math.floor(raw.dmg * 110 / 100))
		expect(pair.maxHp).toBe(math.floor(raw.maxHp * 110 / 100))
		-- the full pack with the Titan: three others
		local pack = BattleRules.lineup({ owned("lion"), owned("jackal"), owned("meerkat"), owned("elephant") }, 1)
		expect(pack[1].dmg).toBe(math.floor(raw.dmg * 130 / 100))
		local titan = BattleRules.fighter(owned("elephant"), 1, 4)
		expect(pack[4].maxHp).toBe(math.floor(titan.maxHp * 130 / 100))
		expect(pack[4].hp).toBe(pack[4].maxHp)
		-- solitary teammates do not count as pack
		expect(BattleRules.lineup({ owned("lion"), owned("rhino"), owned("cheetah") }, 1)[1].dmg).toBe(raw.dmg)
	end)

	it("gives a solitary animal 25% when no teammate shares its role", function()
		local raw = BattleRules.fighter(owned("cheetah"), 1, 1)
		local alone = BattleRules.lineup({ owned("cheetah") }, 1)[1]
		expect(alone.dmg).toBe(math.floor(raw.dmg * 125 / 100))
		expect(alone.maxHp).toBe(math.floor(raw.maxHp * 125 / 100))
		-- a different role beside it keeps the bonus, for both
		local two = BattleRules.lineup({ owned("cheetah"), owned("rhino") }, 1)
		expect(two[1].dmg).toBe(alone.dmg)
		expect(two[2].maxHp).toBe(math.floor(BattleRules.fighter(owned("rhino"), 1, 2).maxHp * 125 / 100))
		-- another Attack animal beside it removes the bonus
		expect(BattleRules.lineup({ owned("cheetah"), owned("jackal") }, 1)[1].dmg).toBe(raw.dmg)
		local twins = BattleRules.lineup({ owned("rhino"), owned("tortoise") }, 1)
		expect(twins[1].maxHp).toBe(BattleRules.fighter(owned("rhino"), 1, 1).maxHp)
	end)
end)

describe("BattleRules.battle", function()
	it("loses with no team, and the player's team wins a mirror match on ties", function()
		expect((BattleRules.battle({}, { owned("jackal") }))).toBe(false)
		local team = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		expect((BattleRules.battle(team, { owned("jackal"), owned("tortoise"), owned("meerkat") }))).toBe(true)
	end)

	it("makes enemies hit the Defence animal first, so it shields a fragile teammate", function()
		local glass = custom("jackal", { health = 1, strength = 400, mana = 0, defence = 0 })
		local wall = { health = 100, defence = 200, strength = 0 }
		local enemy = custom("lion", { strength = 100, health = 150 })
		expect((BattleRules.battle({ glass, custom("tortoise", wall) }, { enemy }))).toBe(true)
		-- the same numbers without the Defence role: the fragile one is hit first and the fight is lost
		expect((BattleRules.battle({ glass, custom("lion", wall) }, { enemy }))).toBe(false)
	end)

	it("lets a Utility animal heal, and calls a fight that runs out of time a loss", function()
		local over = { health = 100, strength = 0, speed = 100, stamina = 100, mana = 0, defence = 0 }
		local attacker = custom("lion", { speed = 0, stamina = 0, mana = 0, health = 4000, defence = 0 })
		-- without healing the target falls in half a minute
		local won, _, took = BattleRules.battle({ attacker }, { custom("lion", over) })
		expect(won).toBe(true)
		expect(took < 40).toBeTruthy()
		-- the same numbers on a healer: it heals more than it takes, so time runs out
		won, _, took = BattleRules.battle({ attacker }, { custom("meerkat", over) })
		expect(won).toBe(false)
		expect(took > BattleRules.MAX_SECONDS - 5 and took <= BattleRules.MAX_SECONDS).toBeTruthy()
	end)

	it("lets one of each role beat three of any one animal of the same rarity, from either side", function()
		for _, ids in { { "jackal", "tortoise", "meerkat" }, { "cheetah", "rhino", "flamingo" } } do
			local mixed = {}
			for _, id in ids do
				table.insert(mixed, owned(id))
			end
			for _, id in ids do
				expect((BattleRules.battle(three(id), mixed))).toBe(false)
				expect((BattleRules.battle(mixed, three(id)))).toBe(true)
			end
		end
	end)

	it("lets the Titan in the fourth slot turn a lost fight", function()
		local team = { owned("jackal"), owned("tortoise"), owned("meerkat") }
		local foes = { owned("cheetah"), owned("rhino"), owned("flamingo") }
		expect((BattleRules.battle(team, foes))).toBe(false)
		table.insert(team, owned("elephant"))
		expect((BattleRules.battle(team, foes))).toBe(true)
	end)

	it("always ends: healers against healers, and absurd stats stop at the attack limit", function()
		local won, _, took = BattleRules.battle({ custom("meerkat") }, { custom("meerkat") })
		expect(won).toBe(true)
		expect(took < BattleRules.MAX_SECONDS).toBeTruthy()
		local endless = { speed = 1e300, stamina = 1e300, health = 1e12 }
		local lost, actions = BattleRules.battle({ custom("tortoise", endless) }, { custom("tortoise", endless) })
		expect(lost).toBe(false)
		expect(actions).toBe(BattleRules.MAX_ACTIONS)
	end)
end)

local function foeAt(id: string, mult: number): StationRules.Owned
	local stats = {} :: any
	for k, v in (StationConfig.foe(id) :: StationConfig.Foe).stats :: any do
		stats[k] = math.max(1, math.floor(v * mult))
	end
	return { s = id, stats = stats } :: any
end

describe("BattleRules revive (decisions 0104, 0105)", function()
	it("lets the Necromancer's power attacks raise each fallen ally once, at REVIVE_PCT of its HP", function()
		local log = {}
		BattleRules.battle(three("lion"), { foeAt("shadow_knight", 0.3), foeAt("necromancer", 4) }, log)
		local raised, seen = {}, false
		for _, h in log do
			for _, r in h.revives or {} do
				seen = true
				expect(h.side).toBe(2)
				expect(h.power).toBe(true)
				raised[r.slot] = (raised[r.slot] or 0) + 1
				local max = BattleRules.lineup({ foeAt("shadow_knight", 0.3), foeAt("necromancer", 4) }, 2)[1].maxHp
				expect(r.hp).toBe(math.max(1, math.floor(max * BattleRules.REVIVE_PCT / 100)))
			end
		end
		expect(seen).toBe(true)
		expect(raised[1]).toBe(1) -- once, and only the knight (the Necromancer never raises itself)
		expect(raised[2]).toBeNil()
	end)

	it("raises several fallen allies with one power attack, never more than REVIVE_MAX", function()
		local wave = {
			foeAt("shadow_knight", 0.2),
			foeAt("shadow_knight", 0.2),
			foeAt("shadow_knight", 0.2),
			foeAt("shadow_knight", 0.2),
		}
		table.insert(wave, foeAt("necromancer", 6))
		local log = {}
		BattleRules.battle(three("lion"), wave, log)
		local most, raised = 0, {}
		for _, h in log do
			local n = #(h.revives or {})
			most = math.max(most, n)
			for _, r in h.revives or {} do
				raised[r.slot] = (raised[r.slot] or 0) + 1
				expect(raised[r.slot]).toBe(1) -- each still only once
			end
		end
		expect(most > 1).toBe(true)
		expect(most <= BattleRules.REVIVE_MAX).toBe(true)
	end)

	it("never raises anyone for a team of animals", function()
		local log = {}
		BattleRules.battle(three("lion"), three("jackal"), log)
		for _, h in log do
			expect(h.revives).toBeNil()
		end
	end)
end)

describe("BattleRules sweep and the Battle Priest (decision 0105)", function()
	it("gives the dragons and the Siege Golem a power attack that strikes every animal standing", function()
		for _, id in { "siege_golem", "dark_drake", "shadow_dragon", "ancient_alpha_dragon" } do
			expect((StationConfig.foe(id) :: StationConfig.Foe).ability).toBe("sweep")
		end
		local log = {}
		BattleRules.battle(three("lion"), { foeAt("dark_drake", 2) }, log)
		local hp, seen = {}, false
		for slot, f in BattleRules.lineup(three("lion"), 1) do
			hp[slot] = f.maxHp
		end
		for _, h in log do
			if h.side == 2 then
				local up = 0
				for _, v in hp do
					up += if v > 0 then 1 else 0
				end
				-- a power attack strikes every lion still up, a normal attack one
				expect(1 + #(h.also or {})).toBe(if h.power then up else 1)
				seen = seen or (h.power and up > 1)
				hp[h.tslot] = h.hp
				for _, x in h.also or {} do
					hp[x.slot] = x.hp
				end
			end
		end
		expect(seen).toBe(true)
	end)

	it("keeps every other foe's power attack on one animal", function()
		local log = {}
		BattleRules.battle(three("lion"), { foeAt("ogre_enforcer", 1), foeAt("darkcaster", 1) }, log)
		for _, h in log do
			if h.side == 2 then
				expect(h.also).toBeNil()
			end
		end
	end)

	it("heals the Battle Priest's whole side with its power attack", function()
		local log = {}
		BattleRules.battle(
			three("lion"),
			{ foeAt("shadow_knight", 1), foeAt("shadow_knight", 1), foeAt("battle_priest", 3) },
			log
		)
		local seen = false
		for _, h in log do
			if h.side == 2 and h.slot == 3 and h.power then
				seen = true
				expect(h.heals == nil).toBe(false)
				expect(h.heal).toBeNil()
			elseif h.side == 2 and h.slot == 3 then
				expect(h.heals).toBeNil() -- its normal attacks heal the one most hurt
			end
		end
		expect(seen).toBe(true)
	end)
end)

describe("BattleRules.battle log", function()
	local function team(ids: { string }): { StationRules.Owned }
		local out = {}
		for _, id in ids do
			table.insert(out, owned(id))
		end
		return out
	end

	it("changes nothing about the result, and has one entry per attack in time order", function()
		for _, c in
			{
				{ { "jackal", "tortoise", "meerkat" }, { "cheetah", "rhino", "flamingo" } },
				{ { "lion", "rhino", "meerkat", "elephant" }, { "jackal", "jackal", "jackal" } },
				{ { "meerkat" }, { "meerkat" } },
			}
		do
			local one, two = team(c[1]), team(c[2])
			local won, actions, seconds = BattleRules.battle(one, two)
			local log = {}
			local won2, actions2, seconds2 = BattleRules.battle(one, two, log)
			expect(won2).toBe(won)
			expect(actions2).toBe(actions)
			expect(seconds2).toBe(seconds)
			expect(#log).toBe(actions)
			for i = 2, #log do
				expect(log[i].t >= log[i - 1].t).toBeTruthy()
			end
			expect(log[#log].t).toBe(seconds)
		end
	end)

	it("says who hit whom for how much, and ends with every enemy down when the team wins", function()
		local one, two = team({ "lion", "rhino", "flamingo" }), team({ "jackal", "tortoise", "meerkat" })
		local log = {}
		expect((BattleRules.battle(one, two, log))).toBe(true)
		local hp = { {}, {} }
		for side, t in { one, two } do
			for slot, f in BattleRules.lineup(t, side) do
				hp[side][slot] = f.maxHp
			end
		end
		for _, e in log do
			expect(e.side ~= e.tside).toBeTruthy()
			expect(e.dmg >= 1).toBeTruthy()
			expect(hp[e.side][e.slot] > 0).toBeTruthy() -- the dead do not attack
			expect(hp[e.tside][e.tslot] > 0).toBeTruthy()
			hp[e.tside][e.tslot] -= e.dmg
			expect(hp[e.tside][e.tslot]).toBe(e.hp)
			for _, x in e.also or {} do -- splash and crowd power attacks (decision 0101)
				expect(hp[e.tside][x.slot] > 0).toBeTruthy()
				hp[e.tside][x.slot] -= x.dmg
				expect(hp[e.tside][x.slot]).toBe(x.hp)
			end
			if e.heal then
				hp[e.side][e.heal.slot] = e.heal.hp
			end
			for _, x in e.heals or {} do
				hp[e.side][x.slot] = x.hp
			end
		end
		for _, h in hp[2] do
			expect(h <= 0).toBeTruthy()
		end
	end)

	it("records a healer's heal and a power attack", function()
		local log = {}
		BattleRules.battle(team({ "meerkat", "rhino" }), team({ "rhino", "rhino" }), log)
		local healed, powered = false, false
		for _, e in log do
			healed = healed or e.heal ~= nil
			powered = powered or e.power
		end
		expect(healed).toBe(true)
		expect(powered).toBe(true)
	end)
end)

describe("BattleRules.battle taps (decision 0092)", function()
	local function team(ids: { string }): { StationRules.Owned }
		local out = {}
		for _, id in ids do
			table.insert(out, owned(id))
		end
		return out
	end
	local one, two = team({ "lion", "rhino", "flamingo" }), team({ "rhino", "rhino", "rhino" })

	-- when slot `slot`'s meter first fills in a fight with these taps
	local function filled(log: { BattleRules.Hit }, slot: number): number?
		for _, e in log do
			if e.side == 1 and e.slot == slot and not e.power and e.energy >= 1 then
				return e.t
			end
		end
		return nil
	end

	it("holds a full meter and fires it itself AUTO_FIRE seconds later, as an extra strike", function()
		local log = {}
		BattleRules.battle(one, two, log, {})
		local at = filled(log, 1) :: number
		expect(at == nil).toBe(false)
		local fired: BattleRules.Hit? = nil
		for _, e in log do
			if e.side == 1 and e.slot == 1 and e.power then
				fired = fired or e
			end
			expect(e.tap).toBeNil()
		end
		expect((fired :: BattleRules.Hit).t).toBe(at + BattleRules.AUTO_FIRE)
		expect((fired :: BattleRules.Hit).energy < 1).toBeTruthy()
	end)

	it("fires at a tap's time when the meter is full, and ignores a tap before it fills", function()
		local log = {}
		BattleRules.battle(one, two, log, {})
		local at = filled(log, 1) :: number
		local tapped = {}
		BattleRules.battle(one, two, tapped, { { slot = 1, t = at - 0.5 }, { slot = 1, t = at + 1 } })
		local strikes = {}
		for _, e in tapped do
			if e.tap then
				table.insert(strikes, e)
			end
		end
		expect(#strikes).toBe(1)
		expect(strikes[1].t).toBe(at + 1)
		expect(strikes[1].power).toBe(true)
	end)

	it("changes nothing before a tap's time, so a fight can be replayed with each new tap", function()
		local log = {}
		BattleRules.battle(one, two, log, {})
		local at = (filled(log, 2) or filled(log, 1)) :: number
		local tapped = {}
		BattleRules.battle(one, two, tapped, { { slot = 2, t = at + 0.3 }, { slot = 1, t = at + 0.3 } })
		local i = 1
		while log[i] and log[i].t < at + 0.3 do
			expect(tapped[i].t).toBe(log[i].t)
			expect(tapped[i].dmg).toBe(log[i].dmg)
			expect(tapped[i].tslot).toBe(log[i].tslot)
			i += 1
		end
	end)

	it("keeps the old rule without taps: a power attack fires on the attack that fills the meter", function()
		local log = {}
		BattleRules.battle(one, two, log)
		for _, e in log do
			expect(e.tap).toBeNil()
			if e.side == 1 and e.power then
				expect(e.energy < 1).toBeTruthy()
			end
		end
	end)
end)

describe("BattleRules power scores (decision 0096)", function()
	local LevelRules = require("../src/shared/LevelRules")
	it("grows with every stat, and a side's power is its fighters' with the group bonuses", function()
		local base = BattleRules.powerOf(custom("lion"))
		for _, stat in StationConfig.STATS do
			expect(BattleRules.powerOf(custom("lion", { [stat] = 80 })) > base).toBeTruthy()
		end
		local pack = { owned("jackal"), owned("jackal"), owned("jackal") }
		local alone = 0
		for _, a in pack do
			alone += BattleRules.powerOf(a)
		end
		expect(BattleRules.teamPower(pack) > alone).toBeTruthy() -- the pack bonus
	end)

	it("picks the winner of nearly every wave fight", function()
		local agree, total = 0, 0
		for _, ids in { { "jackal", "tortoise", "meerkat" }, { "lion", "rhino", "meerkat" } } do
			for _, seconds in { 0, 3600 * 24 * 5 } do
				local team = {}
				for _, id in ids do
					local a = owned(id)
					for _, st in StationConfig.STATIONS do
						a = StationRules.train(a, st.id, seconds)
					end
					table.insert(team, a)
				end
				local ours = BattleRules.teamPower(team, 1)
				for wave = 1, 80 do
					total += 1
					if (ours >= LevelRules.power(wave)) == LevelRules.fight(team, wave, {}) then
						agree += 1
					end
				end
			end
		end
		expect(agree / total >= 0.95).toBeTruthy()
	end)
end)

describe("BattleRules fight feel (decision 0097) and run setups (decision 0098)", function()
	local one = { owned("lion"), owned("rhino"), owned("flamingo") }
	local two = { owned("rhino"), owned("rhino"), owned("rhino") }
	local function filled(log: { BattleRules.Hit }, slot: number): number
		for _, e in log do
			if e.side == 1 and e.slot == slot and not e.power and e.energy >= 1 then
				return e.t
			end
		end
		error("never filled")
	end
	local ready = { energy = 0.95 } -- meters fill on the first attack
	local function tapped(log: { BattleRules.Hit }): BattleRules.Hit
		for _, e in log do
			if e.tap then
				return e
			end
		end
		error("no tap")
	end

	it("makes a tap PERFECT_AT after the meter filled a Perfect, PERFECT times as strong", function()
		local solo, foe = { owned("lion") }, { owned("rhino") } -- alone, so no combo changes the numbers
		local base = {}
		BattleRules.battle(solo, foe, base, {}, ready)
		local at = filled(base, 1)
		local plain, perfect = {}, {}
		BattleRules.battle(solo, foe, plain, { { slot = 1, t = at + 1 } }, ready)
		BattleRules.battle(solo, foe, perfect, { { slot = 1, t = at + BattleRules.PERFECT_AT } }, ready)
		expect(tapped(plain).perfect).toBeNil()
		expect(tapped(perfect).perfect).toBe(true)
		expect(tapped(perfect).dmg > tapped(plain).dmg * 1.4).toBeTruthy()
		local late = {}
		BattleRules.battle(
			solo,
			foe,
			late,
			{ { slot = 1, t = at + BattleRules.PERFECT_AT + BattleRules.PERFECT_LATE + 0.05 } },
			ready
		)
		expect(tapped(late).perfect).toBeNil()
	end)

	it("chains power attacks by different animals within COMBO_SECONDS into a combo", function()
		local base = {}
		BattleRules.battle(one, two, base, {}, ready)
		local t = math.max(filled(base, 1), filled(base, 3)) + 0.2
		local log = {}
		BattleRules.battle(one, two, log, { { slot = 1, t = t }, { slot = 3, t = t + 1 } }, ready)
		local combos = {}
		for _, e in log do
			if e.tap then
				table.insert(combos, e.combo or 1)
			end
		end
		expect(combos[2]).toBe(math.min(BattleRules.COMBO_MAX, combos[1] + 1))
	end)

	it("halves enemy power attacks while the shield is up, with a cooldown between shields", function()
		expect(#BattleRules.shields({ { slot = 0, t = 1 }, { slot = 0, t = 3 }, { slot = 0, t = 7.5 } })).toBe(2)
		local tanks = { owned("tortoise"), owned("tortoise"), owned("meerkat") } -- a long fight with enemy power attacks
		local fast = { owned("cheetah"), owned("cheetah"), owned("cheetah") }
		local base = {}
		BattleRules.battle(tanks, fast, base, {})
		local hit: BattleRules.Hit? = nil
		for _, e in base do
			if e.side == 2 and e.power then
				hit = e
				break
			end
		end
		local h = hit :: BattleRules.Hit
		local log = {}
		BattleRules.battle(tanks, fast, log, { { slot = 0, t = h.t - 0.5 } })
		for _, e in log do
			if e.t == h.t and e.side == 2 and e.slot == h.slot then
				expect(e.shielded).toBe(true)
				expect(e.dmg <= math.ceil(h.dmg / 2) + 1).toBeTruthy()
			end
		end
	end)

	it("starts side 1 hurt, knocked out or stronger, and reports its HP at the end", function()
		local won, _, _, ends = BattleRules.battle(one, two, nil, {})
		expect(won).toBe(true)
		expect(#ends).toBe(3)
		for _, share in ends do
			expect(share >= 0 and share <= 1).toBeTruthy()
		end
		local lost = BattleRules.battle(one, two, nil, {}, { hp = { 0, 0, 0 } })
		expect(lost).toBe(false)
		local _, _, slow = BattleRules.battle(one, two, nil, {})
		local _, _, fast = BattleRules.battle(one, two, nil, {}, { dmg = 2 })
		expect(fast < slow).toBeTruthy()
	end)
end)
