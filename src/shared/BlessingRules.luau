--!strict
-- Pure blessing rules for Hundred Demon Night (GDD section E): pool, seeded offers, stacking and
-- the modifiers the rest of the rules read. No Roblox APIs, so Lune can unit-test them.

local Rng = require("./Rng")

local BlessingRules = {}

export type Blessing = { id: string, name: string, max: number, party: boolean, text: string }
export type Stacks = { [string]: number }
export type Modifiers = {
	damageMult: number,
	speedMult: number,
	maxHp: number,
	gaugeRate: number,
	triggerDuration: number,
	charms: number,
	risingCooldown: number,
	healOnKill: number,
	thunderDamage: number,
	foxfire: boolean,
	shockwave: boolean,
	link: boolean,
}

local function blessing(id: string, name: string, max: number, text: string, party: boolean?): Blessing
	return { id = id, name = name, max = max, party = party == true, text = text }
end

local POOL: { Blessing } = {
	blessing("edge", "Sharpened Edge", 3, "+12% damage"),
	blessing("swift", "Swift Steps", 2, "+10% move speed"),
	blessing("iron", "Iron Skin", 3, "+20 max HP, heal 20"),
	blessing("foxfire", "Kitsune Fire", 1, "Finishers launch a fox-fire bolt"),
	blessing("thunder", "Thunder Dash", 2, "Dashing deals 15 damage along the path"),
	blessing("lantern", "Lantern Heart", 2, "Heal 3 HP per kill"),
	blessing("hunger", "Demon Hunger", 2, "+30% Trigger gauge gain"),
	blessing("longnight", "Long Night", 2, "Demon Trigger lasts 3 s longer"),
	blessing("ninetails", "Nine Tails", 1, "+1 charm"),
	blessing("storm", "Rising Storm", 2, "Rising Slash cooldown -1.5 s"),
	blessing("shockwave", "Shockwave", 1, "Rising Slash hits all around you"),
	blessing("link", "Spirit Link", 1, "Reviving heals both of you to full", true),
}
BlessingRules.POOL = POOL
BlessingRules.FOXFIRE = { damage = 20, range = 30, speed = 60, width = 2 }
BlessingRules.THUNDER = { width = 3, window = 0.35 }

function BlessingRules.get(id: string): Blessing?
	for _, b in POOL do
		if b.id == id then
			return b
		end
	end
	return nil
end

function BlessingRules.eligible(stacks: Stacks, partySize: number): { string }
	local ids = {}
	for _, b in POOL do
		if (stacks[b.id] or 0) < b.max and (not b.party or partySize > 1) then
			table.insert(ids, b.id)
		end
	end
	return ids
end

function BlessingRules.offer(stacks: Stacks, partySize: number, seed: Rng.State): { string }
	local remaining = BlessingRules.eligible(stacks, partySize)
	local picks = {}
	local state = seed
	while #picks < 3 and #remaining > 0 do
		local i
		i, state = Rng.int(state, 1, #remaining)
		table.insert(picks, table.remove(remaining, i))
	end
	return picks
end

function BlessingRules.apply(stacks: Stacks, id: string): (Stacks, boolean)
	local b = BlessingRules.get(id)
	if b == nil or (stacks[id] or 0) >= b.max then
		return stacks, false
	end
	local c = table.clone(stacks)
	c[id] = (stacks[id] or 0) + 1
	return c, true
end

function BlessingRules.modifiers(stacks: Stacks): Modifiers
	local function n(id: string): number
		return stacks[id] or 0
	end
	return {
		damageMult = 1 + 0.12 * n("edge"),
		speedMult = 1 + 0.1 * n("swift"),
		maxHp = 100 + 20 * n("iron"),
		gaugeRate = 1 + 0.3 * n("hunger"),
		triggerDuration = 8 + 3 * n("longnight"),
		charms = 1 + n("ninetails"),
		risingCooldown = math.max(2, 5 - 1.5 * n("storm")),
		healOnKill = 3 * n("lantern"),
		thunderDamage = 15 * n("thunder"),
		foxfire = n("foxfire") > 0,
		shockwave = n("shockwave") > 0,
		link = n("link") > 0,
	}
end

return BlessingRules
