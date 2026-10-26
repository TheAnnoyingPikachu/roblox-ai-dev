--!strict
-- Hundred Demon Night combat on the server (GDD C, decision 0007). The client sends only
-- Combat(action); every check, hit test, damage number, gauge and style point is decided here
-- by CombatRules, BlessingRules and StyleRules against the server's replicated root position.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlessingRules = require(Shared:WaitForChild("BlessingRules"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local NightProgress = require(Shared:WaitForChild("NightProgress"))
local RunRules = require(Shared:WaitForChild("RunRules"))
local StyleRules = require(Shared:WaitForChild("StyleRules"))
local Enemies = require(script.Parent:WaitForChild("Enemies"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local State = require(script.Parent:WaitForChild("State"))

type Vec3 = CombatRules.Vec3

export type Entry = {
	player: Player,
	fighter: CombatRules.Fighter,
	style: StyleRules.State,
	tally: NightProgress.Tally,
	sample: Vec3?,
	sampleAt: number, -- server time of `sample`
	downedAt: Vec3?, -- where the player went down; revives use it, not the client-owned root
	speed: number, -- last WalkSpeed written
}

local Combat = {}

local BASE_WALK = 24
local BASE_JUMP = 55
local LIVE_STATES = { Countdown = true, Wave = true, Break = true }
local ACTIONS = { attack = true, skill = true, dash = true, trigger = true }

local entries: { [number]: Entry } = {}

type Bolt = { id: number, owner: number, pos: Vector3, dir: Vector3, left: number }
type Path = { owner: number, from: Vector3, at: number, damage: number }
local bolts: { Bolt } = {}
local paths: { Path } = {}

local function vec(v: Vector3): Vec3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function v3(v: Vec3): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function modifiers(userId: number): BlessingRules.Modifiers?
	local p = RunRules.find(State.run, userId)
	return p and BlessingRules.modifiers(p.stacks)
end

local function addStyle(entry: Entry, event: string)
	entry.style = StyleRules.add(entry.style, event)
end

local function heal(userId: number, amount: number)
	if amount > 0 then
		State.run = RunRules.heal(State.run, userId, amount)
	end
end

type Hit = { e: number, a: number, p: Vector3 }

-- Damages each target once and returns the Fx list, the damage dealt, enemies launched and
-- whether any target was airborne. Kills are credited to `entry` (killing blows only).
local function strike(
	entry: Entry,
	targets: { CombatRules.Target },
	base: number,
	mods: BlessingRules.Modifiers,
	finisher: boolean,
	launch: boolean,
	from: Vec3,
	t: number,
	knockback: number?
): ({ Hit }, number, number, boolean)
	local userId = entry.player.UserId
	local trigger = CombatRules.triggerActive(entry.fighter, t)
	local list: { Hit } = {}
	local dealt, launched, airHit = 0, 0, false
	for _, target in targets do
		local e = Enemies.get(target.id)
		if e and e.hp > 0 then
			local airborne = t < e.airborneUntil
			local amount = CombatRules.damage(base, mods.damageMult, airborne, trigger, target.mult)
			local launches = launch and CombatRules.canLaunch(e.class)
			local killed = Enemies.damage(target.id, amount, userId, finisher, trigger, launch, from, t, knockback)
			table.insert(list, { e = target.id, a = amount, p = v3(target.pos) })
			dealt += amount
			airHit = airHit or airborne
			if launches and not killed then
				launched += 1
			end
			if killed then
				entry.tally.kills += 1
				addStyle(entry, "kill")
				heal(userId, mods.healOnKill)
			end
		end
	end
	if #list > 0 then
		entry.fighter = CombatRules.gain(entry.fighter, dealt, mods.gaugeRate, t)
		if trigger then
			heal(userId, CombatRules.TRIGGER.healPerHit * #list)
		end
	end
	return list, dealt, launched, airHit
end

-- One swing scores one style event (docs/architecture/night.md 3.9).
local function scoreSwing(entry: Entry, hits: number, launched: number, finisher: boolean, airHit: boolean)
	if hits == 0 then
		return
	end
	addStyle(
		entry,
		if launched > 0 then "launchEnemy" elseif finisher then "finisher" elseif airHit then "airHit" else "hit"
	)
end

local function swing(entry: Entry, root: BasePart, act: string, step: number, finisher: boolean, t: number)
	local userId = entry.player.UserId
	local mods = modifiers(userId)
	if mods == nil then
		return
	end
	Remotes.fx("swing", { u = userId, act = act, step = step, fin = finisher })
	local origin = vec(root.Position)
	local look = root.CFrame.LookVector
	local facing = vec(look)
	local shape, base, launch, knockback
	if act == "skill" then
		shape, base, launch = CombatRules.skillSwing(mods.shockwave), CombatRules.SKILL.damage, true
	else
		local weapon = CombatRules.weapon(entry.fighter.weapon) or CombatRules.WEAPONS[1]
		shape, base, launch, knockback = CombatRules.attackSwing(weapon), weapon.damage[step], false, weapon.knockback
	end
	local hit = CombatRules.hits(origin, facing, Enemies.targets(), shape)
	local list, _, launched, airHit = strike(entry, hit, base, mods, finisher, launch, origin, t, knockback)
	entry.tally.launches += launched
	scoreSwing(entry, #list, launched, finisher, airHit)
	if #list > 0 then
		Remotes.fx("hit", { u = userId, fin = finisher, list = list })
	end
	if finisher and mods.foxfire then
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local dir = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.zAxis
		State.nextProjectile += 1
		local fox = BlessingRules.FOXFIRE
		table.insert(
			bolts,
			{ id = State.nextProjectile, owner = userId, pos = root.Position, dir = dir, left = fox.range }
		)
		Remotes.fx("projectile", {
			id = State.nextProjectile,
			what = "foxfire",
			p = root.Position,
			v = dir * fox.speed,
			r = fox.width,
			life = fox.range / fox.speed,
		})
	end
end

-- Remote contract (decision 0007): Combat(action) with no other argument.
local function onCombat(player: Player, ...: any)
	local count = select("#", ...)
	local action = ...
	local userId = player.UserId
	local entry = entries[userId]
	if entry == nil then
		return
	end
	local t = os.clock()
	local allowed
	-- Every event counts toward the rate limit, refused ones included (C10).
	allowed, entry.fighter = CombatRules.allowRequest(entry.fighter, t)
	if not allowed or count ~= 1 or type(action) ~= "string" or not ACTIONS[action] then
		return
	end
	local run = State.run
	if not LIVE_STATES[run.state] or not RunRules.isAlive(run, userId) then
		return
	end
	local root = rootOf(player)
	local mods = modifiers(userId)
	if root == nil or mods == nil then
		return
	end
	local f = entry.fighter
	-- Attacks and Thunder Dash paths start only near the last server sample (QA M1, m2).
	local trusted = CombatRules.nearSample(entry.sample, vec(root.Position))
	if action == "attack" then
		if not trusted or CombatRules.guarded(f, t) then
			return
		end
		local ok, next, step = CombatRules.attack(f, t)
		if ok then
			entry.fighter = next
			swing(entry, root, "attack", step, CombatRules.isFinisher(next), t)
		end
	elseif action == "skill" then
		if not trusted or CombatRules.guarded(f, t) then
			return
		end
		local ok, next = CombatRules.skill(f, t, mods.risingCooldown)
		if ok then
			entry.fighter = next
			swing(entry, root, "skill", 0, false, t)
		end
	elseif action == "dash" then
		local ok, next = CombatRules.dash(f, t)
		if ok then
			entry.fighter = next
			State.run = RunRules.dash(State.run, userId, t)
			Remotes.fx("dash", { u = userId, thunder = mods.thunderDamage > 0 })
			if mods.thunderDamage > 0 and trusted then
				table.insert(paths, {
					owner = userId,
					from = root.Position,
					at = t + CombatRules.DASH.invulnerable,
					damage = mods.thunderDamage,
				})
			end
		end
	elseif action == "trigger" then
		local ok, next = CombatRules.trigger(f, t, mods.triggerDuration)
		if ok then
			entry.fighter = next
			entry.tally.triggers += 1
			addStyle(entry, "trigger")
			Remotes.fx("swing", { u = userId, act = "trigger", step = 0, fin = false })
		end
	end
end
Remotes.Combat.OnServerEvent:Connect(onCombat)

-- Public API ---------------------------------------------------------------------------------

function Combat.join(player: Player)
	local profile = Profiles.get(player)
	entries[player.UserId] = {
		player = player,
		fighter = CombatRules.newFighter(if profile then profile.weapon else "katana"),
		style = StyleRules.new(),
		tally = NightProgress.newTally(),
		sample = nil,
		sampleAt = -math.huge,
		downedAt = nil,
		speed = -1,
	}
end

function Combat.remove(player: Player)
	local userId = player.UserId
	entries[userId] = nil
	for i = #bolts, 1, -1 do
		if bolts[i].owner == userId then
			Remotes.fx("projectileEnd", { id = bolts[i].id, p = bolts[i].pos })
			table.remove(bolts, i)
		end
	end
	for i = #paths, 1, -1 do
		if paths[i].owner == userId then
			table.remove(paths, i)
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = BASE_WALK
		humanoid.JumpPower = BASE_JUMP
	end
end

function Combat.get(userId: number): Entry?
	return entries[userId]
end

-- Tick step 1: sample participant roots into State.positions and run the teleport guard.
function Combat.sample(t: number)
	local positions: { [number]: Vec3 } = {}
	for _, p in State.run.participants do
		local player = Players:GetPlayerByUserId(p.userId)
		local root = player and rootOf(player)
		if root then
			local pos = vec(root.Position)
			local entry = entries[p.userId]
			if entry then
				-- WalkSpeed 0 does not stop a client-owned root, so a downed player stays where they
				-- fell for ally revives (QA M1).
				if p.downed then
					entry.downedAt = entry.downedAt or entry.sample or pos
					pos = entry.downedAt :: Vec3
				else
					entry.downedAt = nil
				end
				if entry.sample then
					entry.fighter = CombatRules.guard(entry.fighter, entry.sample, pos, t, t - entry.sampleAt)
				end
				entry.sample = pos
				entry.sampleAt = t
			end
			positions[p.userId] = pos
		end
	end
	State.positions = positions
end

function Combat.takeTally(userId: number): NightProgress.Tally
	local entry = entries[userId]
	if entry == nil then
		return NightProgress.newTally()
	end
	local tally = entry.tally
	entry.tally = NightProgress.newTally()
	return tally
end

function Combat.dodged(userId: number)
	local entry = entries[userId]
	if entry then
		addStyle(entry, "dodge")
	end
end

-- Taking damage wipes the meter (C8).
function Combat.resetStyle(userId: number)
	local entry = entries[userId]
	if entry then
		entry.style = StyleRules.reset()
	end
end

-- Targets near the segment a-b, one per enemy id (the highest multiplier), in input order.
local function alongPath(a: Vector3, b: Vector3, width: number): { CombatRules.Target }
	local best: { [number]: CombatRules.Target } = {}
	local order: { number } = {}
	for _, target in Enemies.targets() do
		local band = math.abs(target.pos.y - (a.Y + b.Y) / 2) <= CombatRules.ATTACK_BAND
		if band and CombatRules.nearSegment(vec(a), vec(b), target.pos, width + target.radius) then
			local seen = best[target.id]
			if seen == nil then
				table.insert(order, target.id)
			end
			if seen == nil or target.mult > seen.mult then
				best[target.id] = target
			end
		end
	end
	local list = {}
	for _, id in order do
		table.insert(list, best[id])
	end
	return list
end

local function stepBolts(t: number, dt: number)
	local fox = BlessingRules.FOXFIRE
	for i = #bolts, 1, -1 do
		local bolt = bolts[i]
		local travel = math.min(fox.speed * dt, bolt.left)
		local a, b = bolt.pos, bolt.pos + bolt.dir * travel
		bolt.pos, bolt.left = b, bolt.left - travel
		local entry = entries[bolt.owner]
		local mods = modifiers(bolt.owner)
		local first: CombatRules.Target? = nil
		if entry and mods then
			local nearest = math.huge
			for _, target in alongPath(a, b, fox.width) do
				local d = (v3(target.pos) - a).Magnitude
				if d < nearest then
					first, nearest = target, d
				end
			end
		end
		if first and entry and mods then
			local list = strike(entry, { first }, fox.damage, mods, false, false, vec(a), t, nil)
			Remotes.fx("hit", { u = bolt.owner, fin = false, list = list })
		end
		if first or bolt.left <= 0 or entry == nil then
			Remotes.fx("projectileEnd", { id = bolt.id, p = bolt.pos })
			table.remove(bolts, i)
		end
	end
end

local function stepPaths(t: number)
	for i = #paths, 1, -1 do
		local path = paths[i]
		if t >= path.at then
			table.remove(paths, i)
			local entry = entries[path.owner]
			local mods = modifiers(path.owner)
			local root = entry and rootOf(entry.player)
			if entry and mods and root then
				local to = v3(CombatRules.clampPath(vec(path.from), vec(root.Position), CombatRules.DASH.path))
				local hit = alongPath(path.from, to, BlessingRules.THUNDER.width)
				local list = strike(entry, hit, path.damage, mods, false, false, vec(path.from), t, nil)
				if #list > 0 then
					Remotes.fx("hit", { u = path.owner, fin = false, list = list })
				end
			end
		end
	end
end

-- Tick step 4: foxfire bolts, Thunder Dash paths, style decay and best rank, walk speed.
function Combat.step(t: number, dt: number)
	stepBolts(t, dt)
	stepPaths(t)
	local inWave = State.run.state == "Wave"
	for userId, entry in entries do
		entry.style = StyleRules.decay(entry.style, dt)
		if inWave then
			entry.tally.bestRank = math.max(entry.tally.bestRank, StyleRules.rank(entry.style.points))
		end
		local p = RunRules.find(State.run, userId)
		local character = entry.player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if p and humanoid then
			local mods = BlessingRules.modifiers(p.stacks)
			local trigger = CombatRules.triggerActive(entry.fighter, t)
			local speed = if p.downed
				then 0
				else BASE_WALK * mods.speedMult * (if trigger then CombatRules.TRIGGER.speed else 1)
			if speed ~= entry.speed or humanoid.WalkSpeed ~= speed then
				entry.speed = speed
				humanoid.WalkSpeed = speed
				humanoid.JumpPower = if p.downed then 0 else BASE_JUMP
			end
		end
	end
end

return Combat
