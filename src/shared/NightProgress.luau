--!strict
-- Pure Hundred Demon Night progression (decision 0007, GDD sections F and H): wave and victory
-- rewards, stats, moon tiers, weapons, Blade Arts and masks, plus the saved profile record. The
-- shared reward rules (daily, weekly, quests, cosmetics) come from MetaRules with Night's config.
-- No Roblox APIs, so Lune can unit-test them. Every input comes from the server.

local CombatRules = require("./CombatRules")
local MetaRules = require("./MetaRules")

local NightProgress = {}

export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	wins: number,
	runs: number,
	waves: number,
	kills: number,
	bestTier: number,
	tierPick: number,
	weapon: string,
	blade: string,
	mask: string,
	owned: { [string]: boolean },
	daily: { streak: number, last: number },
	week: { key: number, days: number, lastDay: number, claimed: boolean },
	quests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
}

export type Tally = { kills: number, launches: number, triggers: number, bestRank: number }

export type WaveResult = { wave: number, tier: number, n: number, first: boolean, tally: Tally }

NightProgress.SCHEMA_VERSION = 1
NightProgress.MAX_TIER = 5
NightProgress.TIERS = { "Crescent", "Half", "Full", "Blood", "Eclipse" }
NightProgress.STYLE_MULT = { 1.0, 1.1, 1.2, 1.3, 1.5, 1.75, 2.0 }

local S_RANK = 5 -- StyleRules.RANKS index of "S"

local function cosmetic(
	slot: string,
	id: string,
	name: string,
	colours: { { number } },
	unlock: { [string]: number }
): MetaRules.Cosmetic
	return {
		id = id,
		name = name,
		slot = slot,
		colours = colours,
		level = unlock.level,
		wins = unlock.wins,
		tier = unlock.tier,
		price = unlock.price,
	}
end

-- Blade colours copy Relay's trail colours where the id matches (H4).
local COSMETICS: { MetaRules.Cosmetic } = {
	cosmetic("blade", "steel", "Steel", { { 220, 225, 235 }, { 140, 150, 165 } }, { level = 1 }),
	cosmetic("blade", "sakura", "Sakura", { { 255, 183, 210 }, { 255, 255, 255 } }, { level = 3 }),
	cosmetic("blade", "ember", "Ember", { { 255, 200, 60 }, { 255, 40, 0 } }, { level = 5 }),
	cosmetic("blade", "moonlight", "Moonlight", { { 200, 220, 255 }, { 120, 140, 255 } }, { level = 8 }),
	cosmetic("blade", "shadow", "Demon Shadow", { { 120, 0, 40 }, { 20, 0, 30 } }, { level = 12 }),
	cosmetic(
		"blade",
		"rainbow",
		"Rainbow",
		{ { 255, 60, 60 }, { 255, 220, 60 }, { 60, 255, 120 }, { 60, 160, 255 }, { 200, 80, 255 } },
		{ level = 18 }
	),
	cosmetic("blade", "gold", "Champion Gold", { { 255, 230, 120 }, { 200, 140, 20 } }, { wins = 5 }),
	cosmetic("blade", "lightning", "Lightning", { { 255, 255, 140 }, { 120, 160, 255 } }, { price = 750 }),
	cosmetic("blade", "galaxy", "Galaxy", { { 40, 0, 90 }, { 160, 60, 255 }, { 255, 255, 255 } }, { price = 1500 }),
	cosmetic("blade", "inferno", "Inferno", { { 255, 255, 200 }, { 255, 120, 0 }, { 120, 0, 0 } }, { price = 2500 }),
	cosmetic("blade", "void", "Void", { { 0, 0, 0 }, { 90, 0, 140 } }, { price = 5000 }),
	cosmetic("mask", "none", "No mask", {}, {}),
	cosmetic("mask", "kitsune", "Kitsune", { { 255, 255, 255 }, { 220, 40, 40 } }, { level = 4 }),
	cosmetic("mask", "tengu", "Tengu", { { 200, 30, 30 }, { 20, 20, 20 } }, { level = 10 }),
	cosmetic("mask", "oni", "Oni", { { 170, 20, 20 }, { 255, 210, 80 } }, { wins = 3 }),
	cosmetic("mask", "eclipse", "Eclipse", { { 20, 0, 30 }, { 255, 140, 0 } }, { tier = 5 }),
	cosmetic("mask", "okame", "Okame", { { 255, 245, 235 }, { 230, 90, 110 } }, { price = 600 }),
	cosmetic("mask", "hannya", "Hannya", { { 240, 230, 200 }, { 120, 0, 0 } }, { price = 1000 }),
}
NightProgress.COSMETICS = COSMETICS

local QUEST_POOL: { MetaRules.Quest } = {
	{ id = "nights3", label = "Play 3 nights", stat = "runs", goal = 3, reward = 100 },
	{ id = "waves10", label = "Clear 10 waves", stat = "waves", goal = 10, reward = 100 },
	{ id = "kills60", label = "Defeat 60 yokai", stat = "kills", goal = 60, reward = 100 },
	{ id = "launch30", label = "Launch 30 yokai", stat = "launches", goal = 30, reward = 120 },
	{ id = "trigger5", label = "Use Demon Trigger 5 times", stat = "triggers", goal = 5, reward = 120 },
	{ id = "rankS3", label = "Reach S rank in 3 waves", stat = "rankS", goal = 3, reward = 150 },
	{ id = "general2", label = "Defeat the Oni General twice", stat = "generals", goal = 2, reward = 150 },
	{ id = "boss1", label = "Defeat the Gashadokuro", stat = "bosses", goal = 1, reward = 250 },
}
NightProgress.QUEST_POOL = QUEST_POOL

local CONFIG: MetaRules.Config<Profile> = {
	cosmetics = COSMETICS,
	slots = { blade = "steel", mask = "none" },
	quests = QUEST_POOL,
	daily = { 50, 75, 100, 125, 150, 200, 400 },
	weekly = { days = 5, reward = 500 },
	sanitize = function(record: any): Profile
		return NightProgress.sanitize(record)
	end,
}
NightProgress.CONFIG = CONFIG

local function floor(x: number): number
	return math.floor(x + 1e-9)
end

local function tierMult(tier: number): number
	return 1 + 0.5 * (math.clamp(tier, 1, NightProgress.MAX_TIER) - 1)
end

-- Profile ------------------------------------------------------------------------------------

function NightProgress.defaults(): Profile
	return {
		schemaVersion = NightProgress.SCHEMA_VERSION,
		xp = 0,
		coins = 0,
		wins = 0,
		runs = 0,
		waves = 0,
		kills = 0,
		bestTier = 0,
		tierPick = 1,
		weapon = "katana",
		blade = "steel",
		mask = "none",
		owned = {},
		daily = { streak = 0, last = -1 },
		week = { key = -1, days = 0, lastDay = -1, claimed = false },
		quests = { day = -1, progress = {}, claimed = {} },
	}
end

function NightProgress.levelFor(xp: number): number
	return MetaRules.levelFor(xp)
end

function NightProgress.weaponUnlocked(p: Profile, id: string): boolean
	local w = type(id) == "string" and CombatRules.weapon(id)
	return if w then MetaRules.levelFor(p.xp) >= w.level else false
end

-- H7. Game fields first, so MetaRules' slot checks can read bestTier.
function NightProgress.sanitize(record: any): Profile
	local p = NightProgress.defaults()
	if type(record) ~= "table" then
		return p
	end
	p.runs = MetaRules.count(record.runs, MetaRules.MAX_COUNT)
	p.waves = MetaRules.count(record.waves, MetaRules.MAX_COUNT)
	p.kills = MetaRules.count(record.kills, MetaRules.MAX_COUNT)
	p.bestTier = MetaRules.count(record.bestTier, NightProgress.MAX_TIER)
	p.tierPick = math.max(1, MetaRules.count(record.tierPick, NightProgress.MAX_TIER))
	MetaRules.sanitizeMeta(CONFIG, record, p)
	if type(record.weapon) == "string" and NightProgress.weaponUnlocked(p, record.weapon) then
		p.weapon = record.weapon
	end
	return p
end

function NightProgress.newTally(): Tally
	return { kills = 0, launches = 0, triggers = 0, bestRank = 1 }
end

-- Rewards (F2) -------------------------------------------------------------------------------

function NightProgress.waveRewards(wave: number, tier: number, n: number, bestRank: number): (number, number)
	local style = NightProgress.STYLE_MULT[math.clamp(math.floor(bestRank), 1, #NightProgress.STYLE_MULT)]
	local party = 1 + 0.1 * math.clamp(n - 1, 0, 3)
	local r = tierMult(tier) * style * party
	return floor((15 + 3 * wave) * r), floor((8 + 2 * wave) * r)
end

function NightProgress.victoryRewards(tier: number): (number, number)
	return floor(150 * tierMult(tier)), floor(100 * tierMult(tier))
end

local function pay(p: Profile, xp: number, souls: number)
	p.xp = math.min(MetaRules.MAX_XP, p.xp + xp)
	p.coins = math.min(MetaRules.MAX_COINS, p.coins + souls)
end

-- Rewards, F3 stats and quest progress for one cleared wave.
function NightProgress.applyWave(p: Profile, result: WaveResult, today: number): (Profile, number, number)
	local tally = result.tally
	local xp, souls = NightProgress.waveRewards(result.wave, result.tier, result.n, tally.bestRank)
	local out = NightProgress.sanitize(p)
	pay(out, xp, souls)
	local kills = math.max(0, math.floor(tally.kills))
	out.waves = math.min(MetaRules.MAX_COUNT, out.waves + 1)
	out.kills = math.min(MetaRules.MAX_COUNT, out.kills + kills)
	if result.first then
		out.runs = math.min(MetaRules.MAX_COUNT, out.runs + 1)
	end
	out = MetaRules.addProgress(CONFIG, out, today, {
		waves = 1,
		kills = kills,
		launches = math.max(0, math.floor(tally.launches)),
		triggers = math.max(0, math.floor(tally.triggers)),
		rankS = if tally.bestRank >= S_RANK then 1 else 0,
		generals = if result.wave == 5 then 1 else 0,
		bosses = if result.wave == 10 then 1 else 0,
		runs = if result.first then 1 else 0,
	})
	return out, xp, souls
end

function NightProgress.applyVictory(p: Profile, tier: number, _today: number): (Profile, number, number)
	local xp, souls = NightProgress.victoryRewards(tier)
	local out = NightProgress.sanitize(p)
	pay(out, xp, souls)
	out.wins = math.min(MetaRules.MAX_COUNT, out.wins + 1)
	out.bestTier = math.max(out.bestTier, math.clamp(math.floor(tier), 1, NightProgress.MAX_TIER))
	return out, xp, souls
end

-- Tiers and weapons --------------------------------------------------------------------------

function NightProgress.maxTier(p: Profile): number
	return math.min(NightProgress.MAX_TIER, p.bestTier + 1)
end

function NightProgress.tierFor(p: Profile): number
	return math.clamp(p.tierPick, 1, NightProgress.maxTier(p))
end

function NightProgress.setTier(p: Profile, tier: number): (Profile, boolean)
	if type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or tier > NightProgress.maxTier(p) then
		return p, false
	end
	local out = NightProgress.sanitize(p)
	out.tierPick = tier
	return out, true
end

function NightProgress.equipWeapon(p: Profile, id: string): (Profile, boolean)
	if not NightProgress.weaponUnlocked(p, id) then
		return p, false
	end
	local out = NightProgress.sanitize(p)
	out.weapon = id
	return out, true
end

-- Shared meta (MetaRules with Night's config) ------------------------------------------------

function NightProgress.questsFor(today: number): { MetaRules.Quest }
	return MetaRules.questsFor(QUEST_POOL, today)
end

function NightProgress.isUnlocked(p: Profile, id: string): boolean
	return MetaRules.isUnlocked(CONFIG, p, id)
end

function NightProgress.login(p: Profile, today: number): Profile
	return MetaRules.login(CONFIG, p, today)
end

function NightProgress.claimDaily(p: Profile, today: number): (Profile, boolean, number)
	return MetaRules.claimDaily(CONFIG, p, today)
end

function NightProgress.claimWeekly(p: Profile, today: number): (Profile, boolean, number)
	return MetaRules.claimWeekly(CONFIG, p, today)
end

function NightProgress.claimQuest(p: Profile, today: number, questId: string): (Profile, boolean, number)
	return MetaRules.claimQuest(CONFIG, p, today, questId)
end

function NightProgress.buyCosmetic(p: Profile, id: string): (Profile, boolean)
	return MetaRules.buy(CONFIG, p, id)
end

function NightProgress.equipCosmetic(p: Profile, id: string): (Profile, boolean)
	return MetaRules.equip(CONFIG, p, id)
end

return NightProgress
