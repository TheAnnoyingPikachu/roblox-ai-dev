--!strict
local T = require("./framework")
local MetaRules = require("../src/shared/MetaRules")
local NightProgress = require("../src/shared/NightProgress")
local StyleRules = require("../src/shared/StyleRules")

local describe, it, expect = T.describe, T.it, T.expect
local DAY = 20_000

local function tally(kills: number, launches: number, triggers: number, bestRank: number): NightProgress.Tally
	return { kills = kills, launches = launches, triggers = triggers, bestRank = bestRank }
end

local function wave(w: number, first: boolean, t: NightProgress.Tally?): NightProgress.WaveResult
	return { wave = w, tier = 1, n = 1, first = first, tally = t or NightProgress.newTally() }
end

describe("NightProgress rewards (F2)", function()
	it("pays 465 XP and 290 souls for a solo tier-1 rank-D victory", function()
		local p = NightProgress.defaults()
		local xpTotal, soulTotal = 0, 0
		for w = 1, 10 do
			local xp, souls
			p, xp, souls = NightProgress.applyWave(p, wave(w, w == 1), DAY)
			xpTotal += xp
			soulTotal += souls
		end
		local xp, souls
		p, xp, souls = NightProgress.applyVictory(p, 1, DAY)
		expect(xpTotal + xp).toBe(465)
		expect(soulTotal + souls).toBe(290)
		expect(p.xp).toBe(465)
		expect(p.coins).toBe(290)
		expect(NightProgress.levelFor(p.xp)).toBe(4)
	end)

	it("applies each multiplier", function()
		local function both(w: number, t: number, n: number, rank: number): string
			local xp, souls = NightProgress.waveRewards(w, t, n, rank)
			return `{xp}/{souls}`
		end
		expect(both(1, 1, 1, 1)).toBe("18/10")
		expect(both(1, 3, 1, 1)).toBe("36/20") -- tier x2.0
		expect(both(1, 1, 1, 7)).toBe("36/20") -- SSS x2.0
		expect(both(1, 1, 1, 2)).toBe("19/11") -- C x1.1
		expect(both(1, 1, 1, 5)).toBe("27/15") -- S x1.5
		expect(both(1, 1, 2, 1)).toBe("19/11") -- party x1.1
		expect(both(1, 1, 4, 1)).toBe("23/13") -- party x1.3
		expect(both(1, 1, 6, 1)).toBe("23/13") -- party capped at x1.3
		expect(both(6, 1, 1, 2)).toBe("36/22") -- 20 x 1.1 souls must not drop to 21
		expect(both(10, 5, 4, 7)).toBe("351/218")
	end)

	it("pays the victory bonus by tier", function()
		local xp, souls = NightProgress.victoryRewards(2)
		expect(xp).toBe(225)
		expect(souls).toBe(150)
		xp, souls = NightProgress.victoryRewards(5)
		expect(xp).toBe(450)
		expect(souls).toBe(300)
	end)

	it("keeps STYLE_MULT in step with StyleRules.RANKS and has the combat style events", function()
		expect(#NightProgress.STYLE_MULT).toBe(#StyleRules.RANKS)
		expect(StyleRules.RANKS[5].letter).toBe("S")
		expect(StyleRules.POINTS.launchEnemy).toBe(10)
		expect(StyleRules.POINTS.launch).toBe(14)
		expect(StyleRules.POINTS.dodge).toBe(15)
	end)
end)

describe("NightProgress stats (F3)", function()
	it("counts waves, kills and runs, and quest progress", function()
		local p = NightProgress.applyWave(NightProgress.defaults(), wave(1, true, tally(7, 3, 1, 5)), DAY)
		expect(p.waves).toBe(1)
		expect(p.kills).toBe(7)
		expect(p.runs).toBe(1)
		local q = p.quests.progress
		expect(q.waves).toBe(1)
		expect(q.kills).toBe(7)
		expect(q.launches).toBe(3)
		expect(q.triggers).toBe(1)
		expect(q.rankS).toBe(1)
		expect(q.runs).toBe(1)
		expect(q.generals).toBe(0)
		p = NightProgress.applyWave(p, wave(2, false, tally(2, 0, 0, 4)), DAY)
		expect(p.runs).toBe(1)
		expect(p.waves).toBe(2)
		expect(p.quests.progress.rankS).toBe(1)
	end)

	it("counts generals on wave 5 and bosses on wave 10", function()
		local p = NightProgress.applyWave(NightProgress.defaults(), wave(5, false), DAY)
		expect(p.quests.progress.generals).toBe(1)
		p = NightProgress.applyWave(p, wave(10, false), DAY)
		expect(p.quests.progress.bosses).toBe(1)
	end)

	it("counts a win and raises bestTier on victory", function()
		local p = NightProgress.defaults()
		p.bestTier = 3
		local won = NightProgress.applyVictory(p, 2, DAY)
		expect(won.wins).toBe(1)
		expect(won.bestTier).toBe(3)
		expect(NightProgress.applyVictory(won, 4, DAY).bestTier).toBe(4)
		expect(p.wins).toBe(0)
	end)
end)

describe("NightProgress tiers and weapons (H3)", function()
	it("unlocks a tier by winning the one below and clamps the pick", function()
		local p = NightProgress.defaults()
		expect(NightProgress.maxTier(p)).toBe(1)
		local _, locked = NightProgress.setTier(p, 2)
		expect(locked).toBe(false)
		p.bestTier = 1
		local set, ok = NightProgress.setTier(p, 2)
		expect(ok).toBe(true)
		expect(NightProgress.tierFor(set)).toBe(2)
		set.tierPick = 5
		expect(NightProgress.tierFor(set)).toBe(2)
		p.bestTier = 5
		expect(NightProgress.maxTier(p)).toBe(5)
		expect((NightProgress.setTier(p, 6))).toBe(p)
		local _, frac = NightProgress.setTier(p, 2.5)
		expect(frac).toBe(false)
	end)

	it("unlocks weapons by level", function()
		local p = NightProgress.defaults()
		expect(NightProgress.weaponUnlocked(p, "katana")).toBe(true)
		expect(NightProgress.weaponUnlocked(p, "kodachi")).toBe(false)
		local _, refused = NightProgress.equipWeapon(p, "kodachi")
		expect(refused).toBe(false)
		p.xp = MetaRules.xpForLevel(6)
		local equipped, ok = NightProgress.equipWeapon(p, "kodachi")
		expect(ok).toBe(true)
		expect(equipped.weapon).toBe("kodachi")
		expect(NightProgress.weaponUnlocked(p, "nodachi")).toBe(false)
		expect(NightProgress.weaponUnlocked(p, "spear")).toBe(false)
	end)
end)

describe("NightProgress cosmetics and quests (H4, H5)", function()
	it("equips blades and masks into their own slots", function()
		local p = NightProgress.defaults()
		p.xp = MetaRules.xpForLevel(4)
		local a = NightProgress.equipCosmetic(p, "kitsune")
		local b = NightProgress.equipCosmetic(a, "sakura")
		expect(b.mask).toBe("kitsune")
		expect(b.blade).toBe("sakura")
		local _, eclipse = NightProgress.equipCosmetic(p, "eclipse")
		expect(eclipse).toBe(false)
		p.bestTier = 5
		expect(NightProgress.isUnlocked(p, "eclipse")).toBe(true)
		p.wins = 5
		expect(NightProgress.isUnlocked(p, "gold")).toBe(true)
		expect(NightProgress.isUnlocked(p, "oni")).toBe(true)
	end)

	it("buys with souls", function()
		local p = NightProgress.defaults()
		p.coins = 700
		local bought, ok = NightProgress.buyCosmetic(p, "okame")
		expect(ok).toBe(true)
		expect(bought.coins).toBe(100)
		expect((NightProgress.equipCosmetic(bought, "okame")).mask).toBe("okame")
	end)

	it("lists 18 cosmetics and 8 quests, 3 a day", function()
		expect(#NightProgress.COSMETICS).toBe(18)
		expect(#NightProgress.QUEST_POOL).toBe(8)
		expect(#NightProgress.questsFor(DAY)).toBe(3)
	end)

	it("claims daily and weekly rewards with decision 0006 amounts", function()
		local p, ok, reward = NightProgress.claimDaily(NightProgress.defaults(), DAY)
		expect(ok).toBe(true)
		expect(reward).toBe(50)
		local monday = 7 * 3000 - 3
		for d = 0, 4 do
			p = NightProgress.login(p, monday + d)
		end
		local _, wok, wr = NightProgress.claimWeekly(p, monday + 4)
		expect(wok).toBe(true)
		expect(wr).toBe(500)
	end)

	it("pays a finished quest once", function()
		local quest = NightProgress.questsFor(DAY)[1]
		local p = NightProgress.login(NightProgress.defaults(), DAY)
		p.quests.progress[quest.stat] = quest.goal
		local done, ok, reward = NightProgress.claimQuest(p, DAY, quest.id)
		expect(ok).toBe(true)
		expect(reward).toBe(quest.reward)
		expect((select(2, NightProgress.claimQuest(done, DAY, quest.id)))).toBe(false)
	end)
end)

describe("NightProgress.sanitize (H7)", function()
	it("returns defaults for non-tables", function()
		local p = NightProgress.sanitize("bad")
		expect(p.weapon).toBe("katana")
		expect(p.tierPick).toBe(1)
		expect(p.bestTier).toBe(0)
	end)

	it("clamps tiers and counts", function()
		local p = NightProgress.sanitize({ bestTier = 9, tierPick = 0, runs = -2, kills = 10 ^ 9, waves = 3.5 })
		expect(p.bestTier).toBe(5)
		expect(p.tierPick).toBe(1)
		expect(p.runs).toBe(0)
		expect(p.kills).toBe(MetaRules.MAX_COUNT)
		expect(p.waves).toBe(3)
		expect(NightProgress.sanitize({ tierPick = 7 }).tierPick).toBe(5)
	end)

	it("falls back for unknown or locked weapon, blade and mask", function()
		local p = NightProgress.sanitize({ weapon = "nodachi", blade = "rainbow", mask = "hannya" })
		expect(p.weapon).toBe("katana")
		expect(p.blade).toBe("steel")
		expect(p.mask).toBe("none")
		local q = NightProgress.sanitize({ weapon = "spear", blade = "kitsune", mask = "steel" })
		expect(q.blade).toBe("steel")
		expect(q.mask).toBe("none")
		local r = NightProgress.sanitize({
			xp = MetaRules.xpForLevel(14),
			weapon = "nodachi",
			blade = "moonlight",
			bestTier = 5,
			mask = "eclipse",
			owned = { hannya = true, kitsune = true },
		})
		expect(r.weapon).toBe("nodachi")
		expect(r.blade).toBe("moonlight")
		expect(r.mask).toBe("eclipse")
		expect(r.owned.hannya).toBe(true)
		expect(r.owned.kitsune).toBeNil()
	end)
end)
