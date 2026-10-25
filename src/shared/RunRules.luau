--!strict
-- Pure run state machine for Hundred Demon Night (GDD sections B, E, G and K): joins and leaves,
-- host, waves and breaks, blessing picks, downs, charms and revives. No Roblox APIs, so Lune can
-- unit-test it. Every function returns a new Run; the server keeps the returned value.

local BlessingRules = require("./BlessingRules")
local CombatRules = require("./CombatRules")
local Rng = require("./Rng")

local RunRules = {}

export type Participant = {
	userId: number,
	joinIndex: number,
	hp: number,
	maxHp: number,
	charms: number,
	downed: boolean,
	reviveAt: number?,
	helpTime: number,
	invulnUntil: number,
	dashUntil: number,
	stacks: BlessingRules.Stacks,
	offer: { string },
	picked: boolean,
	clears: number,
}

export type Run = {
	state: string,
	wave: number,
	tier: number,
	seed: number,
	host: number?,
	endsAt: number,
	n: number,
	participants: { Participant },
}

export type TickInput = {
	t: number,
	dt: number,
	cleared: boolean,
	hostTier: number,
	seed: number,
	positions: { [number]: CombatRules.Vec3 },
}

export type Event = { kind: string, wave: number?, n: number?, userId: number?, by: number? }

export type HitResult = string

RunRules.MAX_PARTY = 6
RunRules.COUNTDOWN = 3
RunRules.BREAK = 12
RunRules.END = 8
RunRules.BASE_HP = 100
RunRules.CHARM = { delay = 3, hp = 0.5 }
RunRules.ALLY = { radius = 6, time = 2, hp = 0.4 }
RunRules.REVIVE_INVULN = 2
RunRules.BREAK_HEAL = { heal = 25, stand = 0.5 }

local function newParticipant(userId: number, joinIndex: number): Participant
	return {
		userId = userId,
		joinIndex = joinIndex,
		hp = RunRules.BASE_HP,
		maxHp = RunRules.BASE_HP,
		charms = 1,
		downed = false,
		reviveAt = nil,
		helpTime = 0,
		invulnUntil = -math.huge,
		dashUntil = -math.huge,
		stacks = {},
		offer = {},
		picked = false,
		clears = 0,
	}
end

local function copy(run: Run): Run
	local c = table.clone(run)
	c.participants = {}
	for i, p in run.participants do
		local q = table.clone(p)
		q.stacks = table.clone(p.stacks)
		q.offer = table.clone(p.offer)
		c.participants[i] = q
	end
	return c
end

local function fraction(maxHp: number, f: number): number
	return math.floor(maxHp * f + 1e-9)
end

function RunRules.new(): Run
	return { state = "Idle", wave = 0, tier = 1, seed = 0, host = nil, endsAt = 0, n = 0, participants = {} }
end

function RunRules.find(run: Run, userId: number): Participant?
	for _, p in run.participants do
		if p.userId == userId then
			return p
		end
	end
	return nil
end

-- Mutates `p` (callers pass a copy). Iron Skin heals 20 and Nine Tails adds a charm at once.
local function bless(p: Participant, id: string)
	local stacks, ok = BlessingRules.apply(p.stacks, id)
	if not ok then
		return
	end
	p.stacks = stacks
	p.maxHp = BlessingRules.modifiers(stacks).maxHp
	if id == "iron" and not p.downed then
		p.hp = math.min(p.maxHp, p.hp + 20)
	elseif id == "ninetails" then
		p.charms += 1
	end
end

local function offerFor(run: Run, p: Participant, w: number): { string }
	return BlessingRules.offer(p.stacks, #run.participants, Rng.seed(run.seed, p.joinIndex, w))
end

function RunRules.catchUpCount(run: Run): number
	if run.state == "Wave" or run.state == "Break" then
		return run.wave - 1
	end
	return 0
end

-- B2. From Idle the player becomes host of a new Countdown; the server treats that as the
-- countdown event (play returns no events).
function RunRules.play(run: Run, userId: number, tier: number, seed: number, t: number): (Run, boolean)
	if RunRules.find(run, userId) or #run.participants >= RunRules.MAX_PARTY then
		return run, false
	end
	local r = copy(run)
	if r.state == "Idle" then
		r = RunRules.new()
		r.state = "Countdown"
		r.tier = tier
		r.seed = seed
		r.host = userId
		r.endsAt = t + RunRules.COUNTDOWN
	end
	local p = newParticipant(userId, #r.participants + 1)
	table.insert(r.participants, p)
	-- Catch-up blessing k is offer 1 of the joiner's seeded offer for break k.
	for k = 1, RunRules.catchUpCount(r) do
		local offer = offerFor(r, p, k)
		if offer[1] then
			bless(p, offer[1])
		end
	end
	if r.state == "Break" then
		p.offer = offerFor(r, p, r.wave)
	end
	return r, true
end

local function setHost(r: Run, events: { Event })
	local first = r.participants[1]
	if first and (r.host == nil or RunRules.find(r, r.host) == nil) then
		r.host = first.userId
		table.insert(events, { kind = "host", userId = first.userId })
	end
end

function RunRules.leave(run: Run, userId: number): (Run, { Event })
	local p = RunRules.find(run, userId)
	if p == nil then
		return run, {}
	end
	local r = copy(run)
	table.remove(r.participants, table.find(run.participants, p))
	local events: { Event } = {}
	if #r.participants == 0 then
		if r.state == "Countdown" or r.state == "Wave" or r.state == "Break" then
			return RunRules.new(), { { kind = "idle" } }
		end
		return r, events
	end
	setHost(r, events)
	return r, events
end

local function revive(p: Participant, hp: number, t: number)
	p.downed = false
	p.reviveAt = nil
	p.helpTime = 0
	p.hp = hp
	p.invulnUntil = t + RunRules.REVIVE_INVULN
end

local function startWave(r: Run, w: number, events: { Event })
	r.state = "Wave"
	r.wave = w
	r.endsAt = 0
	r.n = #r.participants
	table.insert(events, { kind = "wave", wave = w, n = r.n })
end

local function timers(r: Run, input: TickInput, events: { Event }): boolean
	local t = input.t
	if r.state == "Countdown" and t >= r.endsAt then
		startWave(r, 1, events)
		return true
	elseif r.state == "Break" and t >= r.endsAt then
		for _, p in r.participants do
			if not p.picked and p.offer[1] then
				bless(p, p.offer[1])
			end
			p.offer = {}
			p.picked = false
		end
		startWave(r, r.wave + 1, events)
		return true
	elseif (r.state == "Victory" or r.state == "Defeat") and t >= r.endsAt then
		if #r.participants == 0 then
			r.state, r.wave, r.n, r.endsAt, r.host = "Idle", 0, 0, 0, nil
			table.insert(events, { kind = "idle" })
			return true
		end
		for i, p in r.participants do
			r.participants[i] = newParticipant(p.userId, i)
		end
		r.state = "Countdown"
		r.wave = 0
		r.n = 0
		r.tier = input.hostTier
		r.seed = input.seed
		r.endsAt = t + RunRules.COUNTDOWN
		setHost(r, events)
		table.insert(events, { kind = "countdown" })
		return true
	end
	return false
end

local function allyRevives(r: Run, input: TickInput, events: { Event })
	for _, p in r.participants do
		if p.downed and p.reviveAt == nil then
			local at = input.positions[p.userId]
			local helper: Participant? = nil
			if at then
				for _, q in r.participants do
					local pos = input.positions[q.userId]
					if not q.downed and pos and CombatRules.flatDistance(at, pos) <= RunRules.ALLY.radius then
						helper = q
						break
					end
				end
			end
			if helper == nil then
				p.helpTime = 0
			else
				p.helpTime += input.dt
				if p.helpTime + 1e-9 >= RunRules.ALLY.time then
					revive(p, fraction(p.maxHp, RunRules.ALLY.hp), input.t)
					if (p.stacks.link or 0) > 0 or (helper.stacks.link or 0) > 0 then
						p.hp = p.maxHp
						helper.hp = helper.maxHp
					end
					table.insert(events, { kind = "revive", userId = p.userId, by = helper.userId })
				end
			end
		end
	end
end

local function startBreak(r: Run, t: number, events: { Event })
	r.state = "Break"
	r.endsAt = t + RunRules.BREAK
	for _, p in r.participants do
		p.offer = offerFor(r, p, r.wave)
		p.picked = false
		if p.downed then
			revive(p, fraction(p.maxHp, RunRules.BREAK_HEAL.stand), t)
			table.insert(events, { kind = "revive", userId = p.userId })
		else
			p.hp = math.min(p.maxHp, p.hp + RunRules.BREAK_HEAL.heal)
		end
	end
	table.insert(events, { kind = "break", wave = r.wave })
end

function RunRules.defeated(run: Run): boolean
	if #run.participants == 0 then
		return false
	end
	for _, p in run.participants do
		if not p.downed or p.reviveAt ~= nil then
			return false
		end
	end
	return true
end

function RunRules.tick(run: Run, input: TickInput): (Run, { Event })
	local r = copy(run)
	local events: { Event } = {}
	local t = input.t
	-- `cleared` describes the wave before this tick, so a wave that started this tick is not judged.
	local changed = timers(r, input, events)
	for _, p in r.participants do
		if p.downed and p.reviveAt and t >= p.reviveAt then
			revive(p, fraction(p.maxHp, RunRules.CHARM.hp), t)
			table.insert(events, { kind = "revive", userId = p.userId })
		end
	end
	allyRevives(r, input, events)
	if r.state == "Wave" and not changed then
		if input.cleared then
			for _, p in r.participants do
				p.clears += 1
			end
			table.insert(events, { kind = "cleared", wave = r.wave, n = #r.participants })
			if r.wave >= 10 then
				r.state = "Victory"
				r.endsAt = t + RunRules.END
				table.insert(events, { kind = "victory" })
			else
				startBreak(r, t, events)
			end
		elseif RunRules.defeated(r) then
			r.state = "Defeat"
			r.endsAt = t + RunRules.END
			table.insert(events, { kind = "defeat" })
		end
	end
	return r, events
end

function RunRules.damage(run: Run, userId: number, amount: number, t: number): (Run, HitResult)
	local p = RunRules.find(run, userId)
	if p == nil or p.downed or run.state ~= "Wave" or amount <= 0 then
		return run, "ignored"
	elseif t < p.invulnUntil then
		return run, "immune"
	elseif t < p.dashUntil then
		return run, "dodge"
	end
	local r = copy(run)
	local q = RunRules.find(r, userId) :: Participant
	q.hp = math.max(0, q.hp - amount)
	if q.hp > 0 then
		return r, "hit"
	end
	q.downed = true
	q.helpTime = 0
	if q.charms > 0 then
		q.charms -= 1
		q.reviveAt = t + RunRules.CHARM.delay
	end
	return r, "down"
end

function RunRules.heal(run: Run, userId: number, amount: number): Run
	local p = RunRules.find(run, userId)
	if p == nil or p.downed then
		return run
	end
	local r = copy(run)
	local q = RunRules.find(r, userId) :: Participant
	q.hp = math.min(q.maxHp, q.hp + math.max(0, amount))
	return r
end

function RunRules.dash(run: Run, userId: number, t: number): Run
	if RunRules.find(run, userId) == nil then
		return run
	end
	local r = copy(run)
	local q = RunRules.find(r, userId) :: Participant
	q.dashUntil = t + CombatRules.DASH.invulnerable
	return r
end

function RunRules.pick(run: Run, userId: number, choice: number): (Run, boolean)
	local p = RunRules.find(run, userId)
	if run.state ~= "Break" or p == nil or p.picked or p.offer[choice] == nil then
		return run, false
	end
	local r = copy(run)
	local q = RunRules.find(r, userId) :: Participant
	bless(q, q.offer[choice])
	q.picked = true
	q.offer = {}
	return r, true
end

function RunRules.isAlive(run: Run, userId: number): boolean
	local p = RunRules.find(run, userId)
	return p ~= nil and not p.downed
end

return RunRules
